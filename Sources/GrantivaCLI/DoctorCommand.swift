import ArgumentParser
import GrantivaCore

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check environment and dependencies."
    )

    @OptionGroup var options: GlobalOptions

    func run() async throws {
        let checks = await DoctorRunner().runAllChecks()

        if options.json {
            print(try JSONOutput.string(checks))
        } else {
            print(DoctorFormatter().format(checks))
        }

        // `grantiva doctor || exit 1` is the intended CI preflight, and it could
        // never fire: every path exited 0. A failing required check exits
        // non-zero now, in both output modes.
        if DoctorRunner.hasFailures(checks) {
            throw ExitCode.failure
        }
    }
}
