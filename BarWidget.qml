import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.mjs" as Model

// Omarchy Vikunja Widget — a keyring-authenticated Vikunja todo list.
// The API token is read once from the OS keyring and passed to curl via the
// environment, never argv. Left click opens the todo list, right click marks
// the next todo done, and the list refreshes every five minutes.
BarWidget {
  id: root
  moduleName: "org.jsongerber.vikunja"

  readonly property string instance: Model.normalizeInstance(setting("instance", null))
  readonly property bool showNoDate: Model.normalizeShowNoDate(setting("showNoDate", null))
  readonly property bool showTitle: Model.normalizeShowTitle(setting("showTitle", null))
  readonly property int syncInterval: Model.normalizeSyncInterval(setting("syncInterval", null))

  property var tasks: []
  property var groups: []
  property var next: null
  property var pendingDone: ({})
  property var projectTitles: ({})
  property string token: ""
  property string loadError: ""
  property string widgetState: "checking"
  property int hiddenCount: 0
  property date now: new Date()
  property string testStatus: "idle"
  property string testMessage: ""
  property string testToken: ""

  readonly property bool syncing: tasksProcess.running || projectsProcess.running
  readonly property bool hasConfig: instance !== "" && token !== ""
  readonly property string configIssue: instance === ""
    ? "no-instance"
    : token === "" ? "no-token" : ""
  readonly property string label: next
    ? "  " + Model.formatLabel(next, now)
    : ""
  readonly property bool showingFallbackIcon: !showTitle || label === ""

  // The token is scoped to the instance URL in the keyring, so a cached token
  // from the previous instance is invalid once the URL changes. Drop it so the
  // next refresh re-reads the keyring (or shows the "no token" setup screen)
  // instead of firing the old token at the new instance.
  onInstanceChanged: {
    if (token !== "") token = ""
  }

  function refresh() {
    if (secretProcess.running || tasksProcess.running || projectsProcess.running || toggleProcess.running) return
    if (instance === "") {
      widgetState = "missing"
      token = ""
      loadError = "Set the instance URL in the widget settings."
      setTasks([])
      return
    }
    if (token === "") {
      secretProcess.command = Model.secretLookupCommand(instance)
      secretProcess.running = true
      return
    }
    startFetch()
  }

  function finishSecretLookup(exitCode) {
    var value = String(secretStdout.text || "").trim()
    if (exitCode !== 0 || value === "") {
      widgetState = "missing"
      token = ""
      loadError = "Vikunja token not found in the keyring.\nOpen the settings (gear icon) to store your API token."
      setTasks([])
      return
    }
    token = value
    widgetState = "ready"
    loadError = ""
    startFetch()
  }

  function startFetch() {
    projectsProcess.command = Model.boundedCommand(Model.projectsCommand(instance))
    projectsProcess.environment = rootTokenEnv()
    projectsProcess.running = true
  }

  function finishProjects(exitCode) {
    projectTitles = ({})
    if (exitCode === 0) {
      try {
        projectTitles = Model.parseProjects(projectsStdout.text || "")
      } catch (error) {
        // Project titles are decorative; task loading should still proceed.
      }
    }
    tasksProcess.command = Model.boundedCommand(Model.tasksCommand(instance))
    tasksProcess.environment = rootTokenEnv()
    tasksProcess.running = true
  }

  function rootTokenEnv() {
    var env = {}
    env[Model.TOKEN_ENV] = token
    return env
  }

  function finishFetch(exitCode) {
    if (exitCode !== 0) {
      var stderr = String(tasksStderr.text || "").trim()
      var detail = Model.truncate(stderr, 320)
      loadError = detail !== ""
        ? "Vikunja failed: " + detail
        : "Could not load todos from Vikunja."
      setTasks([])
      return
    }
    try {
      var parsed = Model.parseTasks(tasksStdout.text || "", projectTitles)
      loadError = ""
      setTasks(parsed)
    } catch (error) {
      loadError = "Vikunja returned unusable output: " + error
      setTasks([])
    }
  }

  function setTasks(list) {
    tasks = list
    next = Model.nextTodo(tasks, pendingDone)
    var built = Model.buildGroups(tasks, now, { showNoDate: showNoDate, pendingDone: pendingDone })
    var limited = Model.truncateGroups(built, Model.MAX_DISPLAY_TASKS)
    groups = limited.groups
    hiddenCount = limited.hidden
  }

  function openTask(task) {
    if (!task) return
    Quickshell.execDetached(["xdg-open", instance + "/tasks/" + task.id])
  }

  function toggleDone(task) {
    if (!task || toggleProcess.running) return
    if (token === "") return
    // Optimistically mark the task done so it renders crossed immediately;
    // finishToggle reverts it if the PATCH fails.
    pendingDone[task.id] = true
    setTasks(tasks)
    toggleProcess.command = Model.boundedCommand(Model.toggleDoneCommand(instance, task.id))
    toggleProcess.environment = rootTokenEnv()
    toggleProcess.running = true
  }

  function finishToggle(exitCode) {
    pendingDone = ({})
    if (exitCode !== 0) {
      setTasks(tasks)
      var detail = Model.truncate(String(toggleStderr.text || "").trim(), 200)
      Quickshell.execDetached([
        "notify-send", "-u", "low", "Vikunja Todos",
        detail !== "" ? detail : "Could not mark the todo as done."
      ])
      return
    }
    refresh()
  }

  function eventValue(value) {
    return value === undefined || value === null ? "" : String(value)
  }

  // Reset the settings-page connection test back to a neutral state.
  function resetTest() {
    testStatus = "idle"
    testMessage = ""
  }

  // Test the configured instance + token with a lightweight authenticated
  // request. `tokenOverride` is the unsaved token still sitting in the
  // settings field; when present it is tested directly instead of the keyring.
  // Otherwise the cached token is used, or looked up from the keyring first.
  function testConnection(tokenOverride) {
    if (testProcess.running || secretTestProcess.running) return
    if (instance === "") {
      testStatus = "error"
      testMessage = "Set an instance URL first."
      return
    }
    var candidate = tokenOverride === undefined || tokenOverride === null
      ? "" : String(tokenOverride).trim()
    if (candidate !== "") {
      testToken = candidate
      runTest()
      return
    }
    if (token === "") {
      testStatus = "running"
      testMessage = "Reading API token from the keyring…"
      secretTestProcess.command = Model.secretLookupCommand(instance)
      secretTestProcess.running = true
      return
    }
    runTest()
  }

  function runTest() {
    testStatus = "running"
    testMessage = "Testing connection…"
    testProcess.command = Model.boundedCommand(Model.testCommand(instance))
    testProcess.environment = testTokenEnv()
    testProcess.running = true
  }

  function testTokenEnv() {
    var env = {}
    env[Model.TOKEN_ENV] = testToken !== "" ? testToken : token
    return env
  }

  function finishSecretTest(exitCode) {
    var value = String(secretTestStdout.text || "").trim()
    if (exitCode !== 0 || value === "") {
      testStatus = "error"
      testMessage = "API token not found in the keyring. Paste it above and try again."
      return
    }
    token = value
    runTest()
  }

  function finishTest(exitCode) {
    var out = String(testStdout.text || "").trim()
    var override = testToken
    testToken = ""
    if (exitCode === 0) {
      testStatus = "ok"
      testMessage = "Connection OK"
      loadError = ""
      widgetState = "ready"
      if (override !== "") {
        // The user tested a token still in the field — persist it so the list
        // actually loads, then refresh.
        storeToken(instance, override)
      } else {
        refresh()
      }
    } else {
      testStatus = "error"
      testMessage = out !== "" ? Model.truncate(out, 240) : "Connection failed."
    }
  }

  // Persist one or more settings to this widget's shell.json entry. Applied
  // locally first so the bar reacts on the click itself; the shell.json write
  // comes back through the bar as the same values. The token is intentionally
  // excluded — it lives in the keyring, never in shell.json.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") entry[key] = root.settings[key]
    for (var k in values) entry[k] = values[k]

    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  // Store a freshly entered token in the keyring, scoped to the instance it
  // belongs to, then re-read it so the widget re-authenticates. The token
  // travels via the VIKUNJA_TOKEN environment variable, never argv.
  function storeToken(instanceUrl, value) {
    var text = String(value || "").trim()
    if (text === "" || tokenStoreProcess.running) return
    var env = {}
    env[Model.TOKEN_ENV] = text
    tokenStoreProcess.environment = env
    tokenStoreProcess.command = Model.storeTokenCommand(instanceUrl)
    tokenStoreProcess.running = true
  }

  function finishStoreToken(exitCode) {
    if (exitCode !== 0) {
      var detail = Model.truncate(String(tokenStoreStderr.text || "").trim(), 200)
      Quickshell.execDetached([
        "notify-send", "-u", "critical", "Vikunja Todos",
        detail !== ""
          ? "Could not store the API token in the keyring: " + detail
          : "Could not store the API token in the keyring."
      ])
      return
    }
    token = ""
    widgetState = "checking"
    loadError = ""
    refresh()
  }

  // Shape used by shell panel routing and the popout coordinator.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    refresh()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (opened) close()
    else open()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: showingFallbackIcon
    ? Math.max(
        fallbackGlyph.tightWidth,
        Style.space(10),
        Math.round(Style.bar.iconSlot * 0.55))
    : plainLabel.implicitWidth

  onSettingsChanged: {
    root.resetTest()
    Qt.callLater(root.refresh)
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: {
      Date.timeZoneUpdated()
      root.now = date
      root.setTasks(root.tasks)
    }
  }

  Timer {
    interval: root.syncInterval * 1000
    repeat: true
    running: root.hasConfig
    onTriggered: root.refresh()
  }

  Process {
    id: secretProcess
    running: false
    stdout: StdioCollector {
      id: secretStdout
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishSecretLookup(exitCode) }
  }

  Process {
    id: projectsProcess
    running: false
    clearEnvironment: false
    stdout: StdioCollector {
      id: projectsStdout
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishProjects(exitCode) }
  }

  Process {
    id: tasksProcess
    running: false
    clearEnvironment: false
    stdout: StdioCollector {
      id: tasksStdout
      waitForEnd: true
    }
    stderr: StdioCollector {
      id: tasksStderr
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishFetch(exitCode) }
  }

  Process {
    id: toggleProcess
    running: false
    clearEnvironment: false
    stderr: StdioCollector {
      id: toggleStderr
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishToggle(exitCode) }
  }

  Process {
    id: tokenStoreProcess
    running: false
    clearEnvironment: false
    stderr: StdioCollector {
      id: tokenStoreStderr
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishStoreToken(exitCode) }
  }

  Process {
    id: secretTestProcess
    running: false
    stdout: StdioCollector {
      id: secretTestStdout
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishSecretTest(exitCode) }
  }

  Process {
    id: testProcess
    running: false
    clearEnvironment: false
    stdout: StdioCollector {
      id: testStdout
      waitForEnd: true
    }
    onExited: function(exitCode) { root.finishTest(exitCode) }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      item.bar = Qt.binding(function() { return root.bar })
      item.settings = Qt.binding(function() { return root.settings })
      item.anchorItem = button
      item.hostWidget = root
    }
  }

  IpcHandler {
    target: "org.jsongerber.vikunja"

    function refresh(): void { root.refresh() }
    function toggle(): void { root.togglePanel() }
    function open(): void { root.open() }
    function close(): void { root.close() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    labelVisible: false
    hasVisualContent: true
    dimmed: root.label === ""
    active: root.next !== null
    useActiveColor: false
    fixedWidth: root.showingFallbackIcon && !vertical ? Style.bar.iconSlot : -1
    fixedHeight: root.showingFallbackIcon && vertical ? Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.tooltipLine

    Text {
      id: plainLabel
      visible: !root.showingFallbackIcon
      anchors.centerIn: parent
      text: root.label
      textFormat: Text.PlainText
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter

      Behavior on color {
        enabled: !button.bar || button.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 160 }
      }
    }

    OpticalGlyph {
      id: fallbackGlyph
      anchors.centerIn: parent
      width: Style.bar.iconCanvas
      height: Style.bar.iconCanvas
      visible: root.showingFallbackIcon
      text: ""
      fontFamily: button.fontFamily
      fontSize: Style.bar.iconFont
      color: button.foreground
    }

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        if (root.next) root.toggleDone(root.next)
        else root.togglePanel()
      } else if (mouseButton === Qt.LeftButton) {
        root.togglePanel()
      }
    }
  }

  // Sanitize external text passed to the host's AutoText tooltip. Shows a
  // summary of the open list rather than repeating the bar label.
  readonly property string tooltipLine: {
    if (widgetState === "checking") return "Checking for Vikunja…"
    if (loadError !== "") return Model.plainLine(loadError)
    var counts = Model.summaryCounts(tasks, now)
    if (counts.open === 0) return "No open todos"
    var parts = [counts.open + " open"]
    if (counts.overdue > 0) parts.push(counts.overdue + " overdue")
    if (counts.noDate > 0) parts.push(counts.noDate + " no date")
    var summary = parts.join(" · ")
    if (next && (!showTitle || Model.labelIsTruncated(next, now)))
      return Model.plainLine(next.title) + "\n────────\n" + summary
    return summary
  }

  Component.onCompleted: {
    now = new Date()
    Qt.callLater(root.refresh)
  }
}
