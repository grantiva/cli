import GrantivaCLI

@main
@available(macOS 15, *)
struct Grantiva {
    static func main() async {
        LoggingBootstrap.bootstrap()
        await GrantivaCommand.main()
    }
}
