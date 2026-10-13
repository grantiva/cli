# Candidate 2 back-collision source diagnosis

## Verdict

**Classification: CLI/WDA selector ambiguity exposed by the accepted demo layout; likely selected-tab misselection, not a stale helper fixture and not hierarchy snapshot timing.** The corrected attempt reaches the required category state. That state contains three `Landmarks` nodes: the excluded application root, an actionable navigation back button (`identifier: BackButton`), and the already-selected tab button (`value: 1`). The frozen CLI submits one broad label predicate, accepts WDA's returned order, and clicks the first element ID. It has no tie-break that makes the navigation back button win over the same-labelled selected tab.

The raw protocol does not return the clicked element ID or attributes, so it cannot prove the winner directly. The behavior makes the selected tab the strong inference: reply 21 reports a successful click but remains on Mountains, and the additive screenshot captured long after the reply and after runner stop still shows Mountains. Reply 20 used the same mechanism to click the distinct `Mountains` back button successfully, which makes a generally broken back action unlikely.

## Frozen identities and observed state

- `findings/evidence/round4-smoke-candidate2/candidate.json` binds CLI source to `22055ff981ae1ffd5aaae69190d7af180f239162`, runner source to `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, and demo source to `84af7581b75134b0e417b254e4317d565f7b73c6`.
- `04-mcp-ios-attempt3/helper/active/requests.jsonl:21-22` sends request 20, `grantiva_tap {label: "Mountains"}`, then request 21, `grantiva_tap {label: "Landmarks"}`.
- `04-mcp-ios-attempt3/helper/active/stdout.raw:20` returns success for Mountains and a category hierarchy containing the actual `Landmarks`/`BackButton`, the `Landmarks` application root, and the selected Landmarks tab. This proves the corrected helper reached the intended L66 collision state.
- `04-mcp-ios-attempt3/helper/active/stdout.raw:21` returns `Tapped on "Landmarks"` but its hierarchy still contains the Mountains category, the `Landmarks`/`BackButton`, and the selected Landmarks tab; it does not contain the required root-list result.
- A preorder traversal of both returned JSON trees locates the visible back button at frame `(16,62,44,44)`, identifier/name `BackButton`, before the visible selected tab at `(67,795,95,54)`, name `Landmarks`, value `1`. This hierarchy order does not establish XCUI query-result order; WDA uses an XCUI query for predicate searches.
- `04a-back-collision-diagnosis/screenshot.json:2-14` records a successful, device-scoped screenshot after runner stop. `after-runner-stop.png` visibly remains on Mountains. With no intervening app interaction, this independently rejects the theory that reply 21 merely sampled before a delayed navigation pop completed.

This must not be conflated with `task8-candidate2-mcp-back-diagnosis.md`: that earlier diagnosis correctly found the prior helper attempted `Landmarks` from the deeper Denali detail, where the immediate back button was `Mountains`. Attempt 3 includes that required Mountains unwind and creates the true back/tab/application collision reviewed in `task8-candidate2-mcp-back-fix-review.md:12-18`.

## Exact selection path

1. `Sources/GrantivaMCP/ToolRegistry.swift:260-273` dispatches `grantiva_tap` to `UITools.tap` and marks a non-error result as a UI mutation.
2. `Sources/GrantivaMCP/Tools/UITools.swift:140-164` calls `driver.tapByLabelMatch(label)`, sleeps 500 ms after the click, then fetches and embeds the hierarchy. The success text means the WDA find and click endpoints returned success; it does not identify the concrete element.
3. `Sources/GrantivaCore/WDA/WDAClient.swift:238-260` defines attribute precedence as label, identifier, placeholder and constructs `label == "Landmarks" AND type != "XCUIElementTypeApplication"`. Application-root exclusion is present and working.
4. `Sources/GrantivaCore/WDA/WDAClient.swift:262-299` posts that predicate to `/session/<id>/elements`, selects `elements.first`, and clicks its ID. No ranking or disambiguation occurs within the label matches.
5. In frozen WDA, `drivers/ios/WebDriverAgent/WebDriverAgentLib/Categories/XCUIElement+FBFind.m:77-93` builds an `XCUIElementQuery` over all descendants matching the predicate and returns all matches in XCUI's query order. The CLI then imposes the accidental semantic rule “first WDA result wins.”

The runner does not choose between these elements. It owns the WDA process/session/port used by the CLI, but the MCP client sends the `/elements` and `/click` requests directly. Therefore the most narrowly owned defect is the frozen CLI's multi-match choice on top of WDA ordering, rather than runner flow selection code.

## Contract and demo context

The original accepted L66 proof required the real `Landmarks` back button to beat a same-named application root and arrive at the root list containing Golden Gate Bridge (`task-5-report.md:76-84`). The corrected helper preserves that criterion and adds a same-labelled selected tab that now exists in the accepted public container. A successful response that leaves Mountains visible does not satisfy L66; the expected back button must still win.

The demo layout is intentional and should remain intact. `ios/Landmarks/ContentView.swift:14-30` keeps a separate `NavigationStack` for each tab inside `PersistentTabContainer`. `ios/Landmarks/PersistentTabContainer.swift:15-44` creates stable public `UITab` models and persistent hosting controllers and updates their roots without replacing tab or navigation identity. `task8-persistent-tab-public-container-report.md:7-13,23-31` records that preserving per-tab navigation state and using public APIs are accepted requirements. This diagnosis does not justify an identifier alias, hierarchy rewriting, private UIKit access, or changing the demo so a selected tab destroys its navigation stack.

## Narrow candidate fix

Keep label-before-identifier-before-placeholder and application exclusion, but make a matching navigation back button deterministic within the label stage. Before the existing broad label query, issue a preferred predicate equivalent to:

`label == <escaped requested label> AND identifier == "BackButton" AND type != "XCUIElementTypeApplication"`

If it returns a usable element, click it and report a label match. If it returns no element, run the existing broad label query unchanged, followed by the existing identifier and placeholder fallbacks. This preserves ordinary label selection and existing annotation semantics while making the contractually required back button win the concrete back-versus-selected-tab collision. It also avoids relying on undocumented XCUI query order.

The implementation should share the current escaping and HTTP/error/retry path rather than duplicating it. A broader interactive-element ranking scheme is not supported by this evidence and would add avoidable behavioral risk.

## Meaningful verification

Add a transport-level CLI test whose preferred-back query returns the `BackButton` ID while the broad label fixture contains a selected tab first; assert that the back ID is clicked and the broad query is not needed. Add controls for no back match (the ordinary first label result remains selected), quoted labels (both predicates remain escaped), application exclusion, and non-200/launch-retry behavior. Existing tests at `Tests/GrantivaCoreTests/WDAClientTests.swift:78-118,183-240` are the appropriate level; a test that only checks predicate strings without competing IDs would miss this defect.

Live acceptance must repeat the corrected attempt-3 sequence on the frozen-style public-container demo: root -> Mountains -> quoted Denali -> Mountains back -> assert category has application root + `Landmarks`/`BackButton` + selected Landmarks tab -> tap `Landmarks` -> require Golden Gate Bridge in the returned hierarchy. Retain the raw JSONL and an independent hierarchy or screenshot after the reply. Also repeat selected/unselected tab transitions and a stack-preservation switch-away/switch-back control so the fix proves back-button precedence without changing the accepted persistent-tab behavior.
