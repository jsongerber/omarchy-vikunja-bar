import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "Model.mjs" as Model

// Omarchy Vikunja Widget popup: next-todo hero followed by a list of open
// todos grouped by due date. The host owns all data and actions so the panel
// stays presentational.
Panel {
  id: root
  moduleName: "org.jasongerber.vikunja"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string instance: hostWidget ? hostWidget.instance : ""
  readonly property bool syncing: hostWidget ? hostWidget.syncing : false
  readonly property string widgetState: hostWidget ? hostWidget.widgetState : "checking"
  readonly property string loadError: hostWidget ? hostWidget.loadError : ""
  readonly property bool hasConfig: hostWidget ? hostWidget.hasConfig : false
  readonly property var groups: hostWidget && hostWidget.groups ? hostWidget.groups : []
  readonly property var next: hostWidget ? hostWidget.next : null
  property date now: hostWidget ? hostWidget.now : new Date()

  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function openTask(task) {
    if (!hostWidget || !task) return
    hostWidget.openTask(task)
    root.close()
  }

  function toggleDone(task) {
    if (!hostWidget || !task) return
    hostWidget.toggleDone(task)
  }

  function syncNow() {
    if (hostWidget) hostWidget.refresh()
  }

  function priorityColor(priority) {
    switch (priority) {
      case 1: return "#6fc276"
      case 2: return "#d2b14f"
      case 3: return "#e08f3c"
      case 4: return "#e05c5c"
      default: return "transparent"
    }
  }

  // ---- Settings view. The gear button toggles it; everything writes back
  //      through the host widget, which persists to shell.json (or the
  //      keyring, for the token).
  property bool showSettings: false

  function openSettings() {
    root.showSettings = true
    Qt.callLater(function() {
      serverField.text = root.hostWidget ? root.hostWidget.instance : ""
      tokenField.text = ""
      if (scroll) scroll.contentY = 0
    })
  }

  function toggleSettings() {
    if (root.showSettings) root.showSettings = false
    else root.openSettings()
  }

  function saveServer() {
    if (!root.hostWidget) return
    var normalized = Model.normalizeInstance(serverField.text)
    if (normalized === root.hostWidget.instance) return
    root.hostWidget.persistSettings({ instance: normalized })
    serverField.text = normalized
  }

  function saveToken() {
    if (!root.hostWidget) return
    var value = String(tokenField.text || "").trim()
    if (value === "") return
    root.hostWidget.storeToken(value)
    tokenField.text = ""
  }

  function saveSyncInterval(value) {
    if (!root.hostWidget) return
    var normalized = Model.normalizeSyncInterval(value)
    if (normalized !== root.hostWidget.syncInterval)
      root.hostWidget.persistSettings({ syncInterval: normalized })
  }

  function toggleShowDone() {
    if (!root.hostWidget) return
    root.hostWidget.persistSettings({ showDone: !root.hostWidget.showDone })
  }

  function toggleShowNoDate() {
    if (!root.hostWidget) return
    root.hostWidget.persistSettings({ showNoDate: !root.hostWidget.showNoDate })
  }

  function openTokenUrl() {
    if (!root.hostWidget || root.hostWidget.instance === "") return
    Qt.openUrlExternally(root.hostWidget.instance + "/user/settings/api-tokens")
  }

  onOpenedChanged: if (opened) {
    if (scroll) scroll.contentY = 0
  } else {
    root.showSettings = false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: serverField.activeFocus || tokenField.activeFocus
        || intervalField.field.activeFocus
        || showDoneToggle.activeFocus || showNoDateToggle.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "s" || text === "S") root.syncNow()
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: scroll.width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: scroll.width
          spacing: Style.space(12)

          Item {
            id: headerRow
            visible: true
            width: parent.width
            height: visible ? Math.max(headingLabel.height, stampLabel.height, settingsButton.height) : 0
            implicitHeight: height

            Text {
              id: headingLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.showSettings ? "SETTINGS" : "TODOS"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1.2
              font.bold: true
            }

            Text {
              id: stampLabel
              visible: !root.showSettings
              anchors.right: actionRow.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: {
                if (root.widgetState === "checking") return "Checking…"
                if (root.widgetState === "missing") return "Not configured"
                if (root.syncing) return "Syncing…"
                if (root.loadError !== "") return "Load failed"
                return ""
              }
              color: root.loadError !== "" ? Color.urgent : Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              id: actionRow
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              PanelActionButton {
                id: settingsButton
                iconText: ""
                tooltipText: root.showSettings ? "Back to todos" : "Settings"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.toggleSettings()
              }

              PanelActionButton {
                id: syncButton
                iconText: ""
                tooltipText: root.syncing ? "Syncing todos…" : "Sync now"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                visible: root.hasConfig && !root.showSettings
                enabled: !root.syncing
                opacity: root.syncing ? 0.6 : 1.0
                onClicked: root.syncNow()

                Text {
                  id: syncIcon
                  anchors.centerIn: parent
                  text: root.syncing ? "" : ""
                  color: syncButton.foreground
                  font.family: syncButton.fontFamily
                  font.pixelSize: syncButton.fontSize

                  RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: root.syncing
                  }

                  onRotationChanged: if (!root.syncing && rotation !== 0) rotation = 0
                }
              }
            }
          }

          Item {
            id: settingsItem
            visible: root.showSettings
            width: parent.width
            height: visible ? settingsColumn.implicitHeight : 0
            implicitHeight: height

            Column {
              id: settingsColumn
              width: parent.width
              spacing: Style.space(12)

              Column {
                width: parent.width
                spacing: Style.space(6)

                PanelSectionHeader {
                  text: "SERVER"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                }

                TextField {
                  id: serverField
                  width: parent.width
                  placeholderText: "https://vikunja.example.com"
                  foreground: root.contentForeground
                  accent: Color.accent
                  fontFamily: root.contentFontFamily
                  onAccepted: root.saveServer()
                  onEditingFinished: root.saveServer()
                }
              }

              Column {
                width: parent.width
                spacing: Style.space(6)

                PanelSectionHeader {
                  text: "API TOKEN"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                }

                TextField {
                  id: tokenField
                  width: parent.width
                  password: true
                  placeholderText: "Stored in keyring — type to replace, then press Enter"
                  foreground: root.contentForeground
                  accent: Color.accent
                  fontFamily: root.contentFontFamily
                  onAccepted: root.saveToken()
                }

                Item {
                  id: tokenLinkRow
                  width: tokenLink.implicitWidth
                  height: tokenLink.implicitHeight

                  Text {
                    id: tokenLink
                    text: "Generate an API token"
                    color: tokenLinkMouse.containsMouse
                      ? Style.hoverStateColor(root.contentForeground, Color.accent)
                      : Color.accent
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.underline: true
                  }

                  MouseArea {
                    id: tokenLinkMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openTokenUrl()
                  }
                }
              }

              Column {
                width: parent.width
                spacing: Style.space(6)

                PanelSectionHeader {
                  text: "SYNC INTERVAL"
                  foreground: root.contentForeground
                  fontFamily: root.contentFontFamily
                }

                NumberField {
                  id: intervalField
                  value: root.hostWidget ? root.hostWidget.syncInterval : Model.SYNC_INTERVAL.defaultValue
                  from: Model.SYNC_INTERVAL.min
                  to: Model.SYNC_INTERVAL.max
                  stepSize: 15
                  foreground: root.contentForeground
                  accent: Color.accent
                  fontFamily: root.contentFontFamily
                  onModified: root.saveSyncInterval(value)
                }

                Text {
                  width: parent.width
                  text: "Seconds between automatic refreshes."
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Toggle {
                id: showDoneToggle
                width: parent.width
                label: "Show completed todos"
                description: "Also show tasks that are already done, dimmed."
                checked: root.hostWidget ? root.hostWidget.showDone : false
                foreground: root.contentForeground
                accent: Color.accent
                fontFamily: root.contentFontFamily
                onClicked: root.toggleShowDone()
              }

              Toggle {
                id: showNoDateToggle
                width: parent.width
                label: "Show todos without a due date"
                description: "Include tasks that have no due date."
                checked: root.hostWidget ? root.hostWidget.showNoDate : true
                foreground: root.contentForeground
                accent: Color.accent
                fontFamily: root.contentFontFamily
                onClicked: root.toggleShowNoDate()
              }
            }
          }

          BorderSurface {
            id: errorItem
            visible: !root.showSettings && root.loadError !== "" && root.hasConfig
            width: parent.width
            height: visible ? errorText.implicitHeight + Style.space(16) : 0
            implicitHeight: height
            radius: Style.cornerRadius
            color: Style.normalFillFor(root.contentForeground, Color.urgent)
            borderSpec: Border.controlSpec("normal", root.contentForeground, Color.urgent)

            Text {
              id: errorText
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(8)
              text: root.loadError
              textFormat: Text.PlainText
              color: Color.urgent
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Item {
            id: setupItem
            visible: !root.showSettings && !!root.hostWidget && !root.hasConfig
            width: parent.width
            height: visible ? setupColumn.implicitHeight : 0
            implicitHeight: height

            Column {
              id: setupColumn
              width: parent.width
              spacing: Style.space(8)

              Text {
                width: parent.width
                text: "Connect Vikunja"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                wrapMode: Text.WordWrap
              }

              Text {
                width: parent.width
                text: "Click the gear icon to open the settings and set your instance URL and API token."
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }

              Text {
                width: parent.width
                text: "Create the token under Settings → API Tokens in Vikunja, paste it in the settings page, and the list loads automatically."
                textFormat: Text.PlainText
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }

          Item {
            id: heroItem
            visible: !root.showSettings && root.hasConfig && !!root.next
            width: parent.width
            height: visible ? heroBlock.implicitHeight : 0
            implicitHeight: height

            BorderSurface {
              id: heroBlock
              width: parent.width
              radius: Style.cornerRadius
              color: Style.normalFillFor(root.contentForeground, Color.accent)
              borderSpec: Border.none()
              implicitHeight: heroColumn.implicitHeight + Style.space(20)

              Column {
                id: heroColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                spacing: Style.space(5)

                RowLayout {
                  width: parent.width

                  Text {
                    text: "NEXT"
                    color: Qt.darker(root.contentForeground, 1.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1.2
                    font.bold: true
                  }

                  Item { Layout.fillWidth: true }

                  Text {
                    text: root.next ? Model.dueDateLabel(root.next, root.now) : ""
                    textFormat: Text.PlainText
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                Text {
                  width: parent.width
                  text: root.next ? String(root.next.title) : ""
                  textFormat: Text.PlainText
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  visible: root.next ? root.next.projectTitle !== "" : false
                  text: root.next ? root.next.projectTitle : ""
                  textFormat: Text.PlainText
                  color: Qt.darker(root.contentForeground, 1.4)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  visible: root.next ? root.next.priority > 0 : false
                  text: root.next ? Model.priorityName(root.next.priority) + " priority" : ""
                  textFormat: Text.PlainText
                  color: priorityColor(root.next ? root.next.priority : 0)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                }

                RowLayout {
                  width: parent.width
                  spacing: Style.space(8)

                  Button {
                    id: openButton
                    Layout.fillWidth: true
                    text: "Open"
                    iconText: ""
                    selected: true
                    accent: Color.accent
                    fontFamily: root.contentFontFamily
                    fontSize: Style.font.bodySmall
                    iconSize: Style.font.bodySmall
                    horizontalPadding: Style.space(12)
                    verticalPadding: Style.space(7)
                    onClicked: root.openTask(root.next)
                  }

                  Button {
                    id: doneButton
                    Layout.fillWidth: true
                    text: "Mark Done"
                    iconText: ""
                    bordered: true
                    foreground: root.contentForeground
                    fontFamily: root.contentFontFamily
                    fontSize: Style.font.bodySmall
                    iconSize: Style.font.bodySmall
                    horizontalPadding: Style.space(12)
                    verticalPadding: Style.space(7)
                    onClicked: root.toggleDone(root.next)
                  }
                }
              }
            }
          }

          Item {
            id: emptyItem
            visible: !root.showSettings
              && root.hasConfig
              && root.loadError === ""
              && root.groups.length === 0
            width: parent.width
            height: visible ? emptyColumn.implicitHeight + Style.space(16) : 0
            implicitHeight: height

            Column {
              id: emptyColumn
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ""
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.display
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No open todos"
                color: Qt.darker(root.contentForeground, 1.3)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "You are all caught up."
                color: Qt.darker(root.contentForeground, 1.6)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }

          Item {
            id: groupsItem
            visible: !root.showSettings && root.hasConfig && root.groups.length > 0
            width: parent.width
            height: visible ? groupsColumn.implicitHeight : 0
            implicitHeight: height

            Column {
              id: groupsColumn
              width: parent.width
              spacing: Style.space(10)

              Repeater {
                model: root.groups

                Item {
                  id: groupItem
                  required property var modelData
                  required property int index
                  readonly property var group: modelData
                  width: parent.width
                  height: groupColumn.implicitHeight
                  implicitHeight: height

                  Column {
                    id: groupColumn
                    width: parent.width
                    spacing: Style.space(4)

                    PanelSeparator {
                      visible: groupItem.index > 0 || heroItem.visible
                      foreground: root.contentForeground
                      strength: 0.1
                    }

                    RowLayout {
                      spacing: Style.space(6)

                      PanelSectionHeader {
                        text: groupItem.group.title
                        foreground: root.contentForeground
                        fontFamily: root.contentFontFamily
                        leftPadding: Style.space(4)
                      }

                      PanelSectionHeader {
                        text: groupItem.group.items.length + ""
                        foreground: root.contentForeground
                        fontFamily: root.contentFontFamily
                        opacity: 0.55
                      }
                    }

                    Repeater {
                      model: groupItem.group.items

                      CursorSurface {
                        id: taskRow
                        required property var modelData
                        required property int index
                        readonly property var todo: modelData
                        readonly property bool done: modelData.done === true
                        width: parent.width
                        hasCursor: false
                        foreground: root.contentForeground
                        accent: Color.accent
                        opacity: done ? 0.45 : 1.0
                        implicitHeight: Math.max(Style.space(32), taskLayout.implicitHeight + Style.space(8))

                        Item {
                          id: priorityMarker
                          anchors.left: parent.left
                          anchors.leftMargin: Style.space(6)
                          anchors.verticalCenter: parent.verticalCenter
                          width: Style.space(6)
                          height: parent.height - Style.space(8)

                          Rectangle {
                            anchors.centerIn: parent
                            width: taskRow.todo.priority > 0 ? Style.space(2) : 0
                            height: taskRow.todo.priority > 0 ? priorityMarker.height : 0
                            radius: width / 2
                            color: priorityColor(taskRow.todo.priority)
                          }
                        }

                        MouseArea {
                          id: rowMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          acceptedButtons: Qt.LeftButton | Qt.RightButton
                          onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) root.toggleDone(taskRow.todo)
                            else root.openTask(taskRow.todo)
                          }
                        }

                        RowLayout {
                          id: taskLayout
                          anchors.left: parent.left
                          anchors.right: parent.right
                          anchors.verticalCenter: parent.verticalCenter
                          anchors.leftMargin: Style.space(20)
                          anchors.rightMargin: Style.space(10)
                          spacing: Style.space(8)

                          Column {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: Style.space(1)

                            Text {
                              width: parent.width
                              text: taskRow.todo.title
                              textFormat: Text.PlainText
                              color: root.contentForeground
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.body
                              font.strikeout: taskRow.done
                              elide: Text.ElideRight
                              maximumLineCount: 1
                            }

                            Text {
                              width: parent.width
                              visible: taskRow.todo.projectTitle !== ""
                              text: taskRow.todo.projectTitle
                              textFormat: Text.PlainText
                              color: Qt.darker(root.contentForeground, 1.45)
                              font.family: root.contentFontFamily
                              font.pixelSize: Style.font.caption
                              elide: Text.ElideRight
                              maximumLineCount: 1
                            }
                          }

                          Text {
                            Layout.alignment: Qt.AlignVCenter
                            visible: groupItem.group.key === Model.GROUP_LATER
                            text: Model.dueDateLabel(taskRow.todo, root.now)
                            textFormat: Text.PlainText
                            color: Qt.darker(root.contentForeground, 1.35)
                            font.family: root.contentFontFamily
                            font.pixelSize: Style.font.caption
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
