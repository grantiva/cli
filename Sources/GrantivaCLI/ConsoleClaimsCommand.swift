import ArgumentParser
import Foundation
import GrantivaAPI
import GrantivaCore

// MARK: - console claims

@available(macOS 15, *)
struct ConsoleClaimsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "claims",
        abstract: "Manage the custom claims minted into device JWTs.",
        subcommands: [
            ListCommand.self,
            GetCommand.self,
            CreateCommand.self,
            UpdateCommand.self,
            DeleteCommand.self,
            ReorderCommand.self,
            TestCommand.self,
            PreviewCommand.self,
        ]
    )

    static func notFound(_ ref: String) -> String { "claim not found: \(ref)" }

    enum ClaimType: String, ExpressibleByArgument, CaseIterable {
        case `static`, conditional, dynamic, external
    }

    enum DataType: String, ExpressibleByArgument, CaseIterable {
        case string, number, boolean, array, object, date
    }

    // MARK: - Shared option groups

    /// The type-specific configuration for create and test. JSON-valued
    /// options accept inline JSON or `@path` to read a file.
    struct DefinitionOptions: ParsableArguments {
        @Option(name: .long, help: "Display name. Defaults to the claim key.")
        var name: String?

        @Option(name: .long, help: "Claim type: static, conditional, dynamic, or external.")
        var type: ClaimType

        @Option(name: .customLong("data-type"), help: "Value type: string, number, boolean, array, object, or date. Default string.")
        var dataType: DataType = .string

        @Option(name: .long, help: "Description.")
        var description: String?

        @Option(name: .long, help: "Static value (for --type static).")
        var value: String?

        @Option(name: .long, help: "Conditional rules as a JSON array, or @file.json (for --type conditional).")
        var rules: String?

        @Option(name: .long, help: "Expression (for --type dynamic).")
        var expression: String?

        @Option(name: .long, help: "External endpoint configuration as JSON, or @file.json (for --type external, Enterprise).")
        var external: String?

        @Option(name: .long, help: "Validation rules as JSON, or @file.json.")
        var validation: String?

        func validate() throws {
            switch type {
            case .static: if value == nil { throw ValidationError("--type static needs --value.") }
            case .conditional: if rules == nil { throw ValidationError("--type conditional needs --rules.") }
            case .dynamic: if expression == nil { throw ValidationError("--type dynamic needs --expression.") }
            case .external: if external == nil { throw ValidationError("--type external needs --external.") }
            }
        }

        func definition(key: String, priority: Int?, isActive: Bool?) throws -> OrgClaimDefinition {
            OrgClaimDefinition(
                claimKey: key,
                claimName: name ?? key,
                claimType: type.rawValue,
                dataType: dataType.rawValue,
                description: description,
                priority: priority,
                isActive: isActive,
                staticValue: value,
                conditionalRules: try rules.map { try ConsoleClaimsCommand.json($0, option: "--rules") },
                dynamicExpression: expression,
                externalConfig: try external.map { try ConsoleClaimsCommand.json($0, option: "--external") },
                validationRules: try validation.map { try ConsoleClaimsCommand.json($0, option: "--validation") }
            )
        }
    }

    /// A simulated device for test and preview.
    struct DeviceOptions: ParsableArguments {
        @Option(name: .customLong("device-model"), help: "Simulated device model, e.g. iPhone16,1.")
        var deviceModel: String?

        @Option(name: .customLong("os-version"), help: "Simulated OS version, e.g. 18.0.")
        var osVersion: String?

        @Option(name: .customLong("app-version"), help: "Simulated app version.")
        var appVersion: String?

        @Option(name: .customLong("risk-score"), help: "Simulated risk score, 0–100.")
        var riskScore: Int?

        @Option(name: .customLong("attestation-count"), help: "Simulated attestation count.")
        var attestationCount: Int?

        @Flag(name: .long, help: "Simulate a jailbroken device.")
        var jailbroken = false

        @Option(name: .long, help: "Simulated country code, e.g. CA.")
        var country: String?

        @Option(name: .long, help: "Extra evaluation data as key=value. Repeatable.")
        var data: [String] = []

        func validate() throws {
            if let riskScore, !(0...100).contains(riskScore) { throw ValidationError("--risk-score must be 0–100.") }
            for pair in data {
                guard let eq = pair.firstIndex(of: "="), eq != pair.startIndex else {
                    throw ValidationError("--data expects key=value, got '\(pair)'.")
                }
            }
        }

        func context() -> OrgClaimTestContext? {
            var device = OrgClaimTestDevice(
                deviceModel: deviceModel, osVersion: osVersion, appVersion: appVersion,
                riskScore: riskScore, attestationCount: attestationCount, country: country
            )
            if jailbroken { device.jailbreakDetected = true }
            var additional: [String: String] = [:]
            for pair in data {
                // validate() has already rejected pairs without a non-empty key.
                guard let eq = pair.firstIndex(of: "="), eq != pair.startIndex else { continue }
                additional[String(pair[..<eq])] = String(pair[pair.index(after: eq)...])
            }
            if device.isEmpty, additional.isEmpty { return nil }
            return OrgClaimTestContext(device: device.isEmpty ? nil : device, additionalData: additional.isEmpty ? nil : additional)
        }
    }

    /// Parses inline JSON or `@path`.
    static func json(_ text: String, option: String) throws -> JSONValue {
        var source = text
        if text.hasPrefix("@") {
            let path = String(text.dropFirst())
            guard let data = FileManager.default.contents(atPath: path), let contents = String(data: data, encoding: .utf8) else {
                throw GrantivaError.invalidArgument("\(option): cannot read \(path)")
            }
            source = contents
        }
        do {
            return try JSONValue.parse(source)
        } catch {
            throw GrantivaError.invalidArgument("\(option): not valid JSON")
        }
    }

    // MARK: - list / get

    struct ListCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "list", abstract: "List custom claims in priority order.")

        @OptionGroup var options: GlobalOptions

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let claims: [OrgClaim]
            do { claims = try await client.listClaims() } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.claimsRead) }
            if options.json {
                Output.line(try JSONOutput.string(claims))
            } else {
                Output.line(ConsoleOrgFormat.claimsTable(claims))
            }
        }
    }

    struct GetCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "get", abstract: "Show one claim by key or UUID, including its configuration.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim key or UUID.")
        var claim: String

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let result: OrgClaim
            do { result = try await client.getClaim(claim) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.claimsRead, notFound: ConsoleClaimsCommand.notFound(claim))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(try ConsoleOrgFormat.claimDetail(result))
            }
        }
    }

    // MARK: - create

    struct CreateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "create",
            abstract: "Create a custom claim.",
            discussion: """
                Examples:
                  grantiva console claims create plan --type static --value gold
                  grantiva console claims create region --type conditional --rules @rules.json
                  grantiva console claims create score --type dynamic --data-type number --expression 'risk_score * 2'
                """
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim key: starts with a letter; letters, digits and underscores only.")
        var key: String

        @OptionGroup var definition: DefinitionOptions

        @Option(name: .long, help: "Priority (lower evaluates first). Default 0.")
        var priority: Int?

        @Flag(name: .long, help: "Create the claim inactive.")
        var inactive = false

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let body = try definition.definition(key: key, priority: priority, isActive: inactive ? false : nil)
            let claim: OrgClaim
            do { claim = try await client.createClaim(body) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.claimsWrite) }
            if options.json {
                Output.line(try JSONOutput.string(claim))
            } else {
                options.note("Created claim '\(claim.claimKey)'")
                Output.line(try ConsoleOrgFormat.claimDetail(claim))
            }
        }
    }

    // MARK: - update

    struct UpdateCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "update",
            abstract: "Change a claim's name, description, priority, active state, or configuration.",
            discussion: "The claim's type, data type and key are fixed at creation. Only the configuration option matching the claim's type applies."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim key or UUID.")
        var claim: String

        @Option(name: .long, help: "New display name.")
        var name: String?

        @Option(name: .long, help: "New description.")
        var description: String?

        @Option(name: .long, help: "New priority.")
        var priority: Int?

        @Flag(name: .long, inversion: .prefixedNo, help: "Activate or deactivate the claim.")
        var active: Bool?

        @Option(name: .long, help: "New static value.")
        var value: String?

        @Option(name: .long, help: "New conditional rules as JSON, or @file.json.")
        var rules: String?

        @Option(name: .long, help: "New dynamic expression.")
        var expression: String?

        @Option(name: .long, help: "New external configuration as JSON, or @file.json.")
        var external: String?

        @Option(name: .long, help: "New validation rules as JSON, or @file.json.")
        var validation: String?

        func validate() throws {
            if name == nil, description == nil, priority == nil, active == nil, value == nil, rules == nil,
               expression == nil, external == nil, validation == nil {
                throw ValidationError("Nothing to update.")
            }
        }

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let body = UpdateOrgClaimRequest(
                claimName: name,
                description: description,
                isActive: active,
                priority: priority,
                staticValue: value,
                conditionalRules: try rules.map { try ConsoleClaimsCommand.json($0, option: "--rules") },
                dynamicExpression: expression,
                externalConfig: try external.map { try ConsoleClaimsCommand.json($0, option: "--external") },
                validationRules: try validation.map { try ConsoleClaimsCommand.json($0, option: "--validation") }
            )
            let updated: OrgClaim
            do { updated = try await client.updateClaim(claim, body) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.claimsWrite, notFound: ConsoleClaimsCommand.notFound(claim))
            }
            if options.json {
                Output.line(try JSONOutput.string(updated))
            } else {
                Output.line(try ConsoleOrgFormat.claimDetail(updated))
            }
        }
    }

    // MARK: - delete

    struct DeleteCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "delete", abstract: "Delete a claim.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim key or UUID.")
        var claim: String

        @Flag(name: .long, help: "Skip the confirmation prompt (required when stdin is not a TTY).")
        var yes = false

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            try ConsoleSupport.confirm("delete claim '\(claim)'", yes: yes)
            let result: OrgDeleteResponse
            do { result = try await client.deleteClaim(claim) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.claimsDelete, notFound: ConsoleClaimsCommand.notFound(claim))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line("Deleted claim '\(claim)'")
            }
        }
    }

    // MARK: - reorder

    struct ReorderCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "reorder",
            abstract: "Set claim priorities by listing every claim in order.",
            discussion: "Every claim must appear exactly once; the first listed gets priority 0."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim keys or UUIDs, in the desired order.")
        var claims: [String]

        func validate() throws {
            if claims.isEmpty { throw ValidationError("List at least one claim.") }
        }

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let ordered: [OrgClaim]
            do { ordered = try await client.reorderClaims(ReorderOrgClaimsRequest(claimRefs: claims)) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.claimsWrite)
            }
            if options.json {
                Output.line(try JSONOutput.string(ordered))
            } else {
                Output.line(ConsoleOrgFormat.claimsTable(ordered))
            }
        }
    }

    // MARK: - test / preview

    struct TestCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "test",
            abstract: "Evaluate a claim definition against a simulated device without saving it.",
            discussion: "Takes the same definition options as `create`, plus a simulated device."
        )

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim key for the definition under test.")
        var key: String

        @OptionGroup var definition: DefinitionOptions

        @OptionGroup var device: DeviceOptions

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let body = TestOrgClaimRequest(claim: try definition.definition(key: key, priority: nil, isActive: nil), context: device.context())
            let result: OrgClaimTestResponse
            do { result = try await client.testClaim(body) } catch { throw ConsoleSupport.map(error, scope: ConsoleScope.claimsTest) }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(ConsoleOrgFormat.claimEvaluation(result))
            }
        }
    }

    struct PreviewCommand: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "preview", abstract: "Evaluate a saved claim against a simulated device.")

        @OptionGroup var options: GlobalOptions

        @Argument(help: "Claim key or UUID.")
        var claim: String

        @OptionGroup var device: DeviceOptions

        func run() async throws { try await run(client: ConsoleSupport.makeOrgClient()) }

        func run(client: OrgClient) async throws {
            let result: OrgClaimTestResponse
            do { result = try await client.previewClaim(claim, PreviewOrgClaimRequest(context: device.context())) } catch {
                throw ConsoleSupport.map(error, scope: ConsoleScope.claimsTest, notFound: ConsoleClaimsCommand.notFound(claim))
            }
            if options.json {
                Output.line(try JSONOutput.string(result))
            } else {
                Output.line(ConsoleOrgFormat.claimEvaluation(result))
            }
        }
    }
}
