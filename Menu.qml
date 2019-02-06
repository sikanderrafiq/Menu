import QtQuick 2.0
import "Menu.js" as Script
import "qmlprivate.js" as P

Item {
    id: container

    property alias interactive: listView.interactive
    property alias backgroundOpacity: bgRect.opacity

    property int        categoryPixelSize:  26
    property string     categoryFontFamily: "Whitney-Medium"
    property int        categoryIndent:     15
    property variant    categoryTextElide:  Text.ElideRight

    property int        itemPixelSize:      26
    property string     itemFontFamily:     "Whitney-Light"
    property int        itemIndent:         45
    property variant    itemTextElide:      Text.ElideRight

    property int        childItemIndent:    70

    property int        topMargin:          60

    width:  324
    height: 350

    property color textColor:   "white"

    property bool onlyOneCategoryCanBeOpen: false

    property ListModel items: ListModel { }

    function addItem(item) {
        if (item.superCategory !== undefined && item.category !== undefined) {
            var sectionkey = item.superCategoryId + "::" + item.superCategory;
            var categoryKey = item.superCategoryId + "::" + item.superCategory + ":::" + item.category;
            var categoryItem = P.priv(container).categoryToItemMap[categoryKey];

            if (categoryItem === undefined) {
                categoryItem = Script.addItem({
                    name: item.category,
                    category: item.superCategory,
                    categoryKey: sectionkey
                });
                P.priv(container).categoryToItemMap[categoryKey] = categoryItem;
            }
            item.categoryKey = sectionkey;
            Script.addChildItem(categoryItem, item);
        }
        else if (item.category !== undefined) {
            var key = item.category;
            var parentItem = P.priv(container).categoryToItemMap[key];

            if (parentItem === undefined) {
                parentItem = Script.addItem({
                    name: item.category
                });
                P.priv(container).categoryToItemMap[key] = parentItem;
            }
            Script.addChildItem(parentItem, item);
        }
        else {
            Script.addItem(item);
        }
    }

    function setItemEnabled(itemIndex, enabled) {
        var internalIndex = Script.toInternalIndex(itemIndex);
        items.get(internalIndex).isEnabled = enabled;
    }

    function setItemText(itemIndex, newText) {
        var internalIndex = Script.toInternalIndex(itemIndex);
        items.get(internalIndex).name = newText;
    }

    function clear() {
        items.clear();
        P.priv(container).onSelectedCallbacks.length = 0;
        P.priv(container).categoryToItemMap = {};
    }

    // selects the item with the specified index and optionally opens its category if open = true.
    // the selected item (or its category, if closed) will be positioned within listView.
    // an index of -1 just de-selects all items.
    function selectItem(x) {
        var isObject = typeof(x) === 'object';

        var externalIndex = isObject ? x.index : x;
        var internalIndex = Script.toInternalIndex(externalIndex);
        if (internalIndex < 0 || !items.get(internalIndex).isEnabled) return;

        var o = {
            index:         internalIndex,
            open:          (isObject) ? x.open : true,
            highlightOnly: (isObject) ? x.highlightOnly : false
        };

        if ((o.open === undefined || o.open) && o.index >= 0 && o.index < listView.count) {
            var obj = items.get(o.index);
            Script.revealCategory(obj.categoryKey, true);
        }

        if (internals.hasChildItems) {
            Script.expandParentIfNeeded(internalIndex);
        }

        if (o.index >= -1 && o.index < listView.count) {
            listView.currentIndex = o.index;
        }

        if (o.index >= 0 && o.index < listView.count) {
            if (o.highlightOnly === undefined || !o.highlightOnly)
                fireCallBack(Script.toExternalIndex(o.index));

            listView.positionViewAtIndex(o.index, ListView.Contain);
         }
    }

    function getSelectedIndex() { // returns -1 if no item is selected
        return Script.toExternalIndex(listView.currentIndex);
    }

    function closeAllCategories() {
        Script.closeCategories();
    }

    function fireCallBack(index)
    {
        if (P.priv(container).onSelectedCallbacks[index] !== undefined)
            P.priv(container).onSelectedCallbacks[index](index);
    }

    Component {
        id: sectionDelegate

        Item {
            id:     sectionDelegateItem
            width:  listView.width
            height: Script.itemHeight

            Rectangle {
                id:           seperator
                width:        320
                height:       1
                color:        "#585859"
                anchors.top:  parent.top
                anchors.left: parent.left
            }

            Text {
                id: contentText
                objectName: "contentText"
                x: container.categoryIndent
                width: parent.width - (container.categoryIndent)
                anchors.verticalCenter: parent.verticalCenter
                text: section.substring(section.indexOf("::") + 2)
                font.pixelSize: container.categoryPixelSize
                font.family: container.categoryFontFamily
                color: container.textColor;
                elide: container.categoryTextElide
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    Script.revealCategory(section, !Script.isCategoryOpen(section));
                }
            }

            Component.onCompleted: {
               seperator.visible = internals.hasChildItems && internals.showSectionSeperator;
               internals.showSectionSeperator = true;
            }
        }
    }

    Component {
        id: itemDelegate

        Item {
            id: delegateItem
            width:  listView.width
            height: h
            clip: true

            property variant self: this

            function highlightWhenSelected() {
                return (level === 1)
                    ? !internals.hasChildItems
                    : true;
            }

            property string namex: name

            Behavior on height {
                id: revealAnimation

                SequentialAnimation {
                    PropertyAnimation   { id: propAnim; duration: Script.itemAnimationDuration }
                    onRunningChanged:  if (Script.firstChildIndex === index) Script.onRunningChangeHandler(running, index, self);
                }
            }

            Rectangle {
                id:         seperatorLine
                width:      320
                height:     1
                color:      "#585859"
                anchors.top: parent.top
                anchors.left: parent.left
                visible:     drawSeperator
            }

            Rectangle {
                id:         highlight
                width:      parent.width
                height:     50
                color:      "#757576"
                anchors.verticalCenter: parent.verticalCenter
                visible:     highlightWhenSelected() && delegateItem.ListView.isCurrentItem
            }

            Image {
                id: icon
                x:  (level === 1) ? container.itemIndent : container.childItemIndent;
                anchors.verticalCenter: highlight.verticalCenter
                sourceSize.width:  22
                sourceSize.height: 23
                source: image
                opacity: isEnabled ? 1.0 : 0.3
            }

            Text {
                id: contentText               
                objectName: "contentText"

                property int leftMargin: image == "" ? 0 : 12

                anchors.left:           icon.right
                anchors.leftMargin:     leftMargin
                anchors.verticalCenter: highlight.verticalCenter

                width: parent.width - icon.width - leftMargin - ((level === 1) ? container.itemIndent : container.childItemIndent)
                text:  name
                font.pixelSize: container.itemPixelSize
                font.family:    container.itemFontFamily

                color: container.textColor;
                elide: container.itemTextElide
                opacity: isEnabled ? 1.0 : 0.3
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    var obj = mapToItem(listView, mouseX, mouseY);
                    var itemIndex = Script.computeIndex(obj);

                    if (isEnabled)
                    {
                        if (internals.hasChildItems) {
                            if (items.get(itemIndex).level === 1)
                                Script.expandOrCollapseItem(itemIndex);
                            else {
                                listView.currentIndex = itemIndex;
                                fireCallBack(Script.toExternalIndex(listView.currentIndex));
                            }
                        }
                        else {
                            listView.currentIndex = itemIndex;
                            fireCallBack(listView.currentIndex);
                        }
                    }
                }
            }
        }
    }

    Rectangle
    {
        id: bgRect

        anchors.fill: parent
        opacity: .95
        color:  "#403f3f"
    }

    Image
    {
        source: "image://app/menulist_shadow.png"
        anchors.left: bgRect.right
    }

    ListView {
        id: listView
        objectName: "listView"
        y: container.topMargin
        width: container.width
        height: container.height - container.topMargin

        model:      items
        delegate:   itemDelegate

        section.delegate: sectionDelegate
        section.property: "categoryKey"

        clip: true
        flickDeceleration: 1000
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.DragAndOvershootBounds
        currentIndex: -1
    }

    Item
    {
        id: internals
        property bool hasChildItems: false
        property bool showSectionSeperator: false
    }

    Component.onCompleted: {
        P.priv(container).onSelectedCallbacks = [];
        P.priv(container).categoryToItemMap = {};
    }
}
