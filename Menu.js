var itemHeight            = 56;
var itemAnimationDuration = 100;
var firstChildIndex;

function addItem(item) {
    items.append({
        name:          item.name.toString(),
        categoryKey:   item.categoryKey,
        category:      item.category !== undefined ? item.category : "",
        drawSeperator: item.drawSeperator !== undefined ? item.drawSeperator : false,
        isEnabled:     item.isEnabled !== undefined ? item.isEnabled : true,
        image:         item.image !== undefined ? item.image : "",
        h:             (item.category !== undefined && item.category !== "") ? 0 : itemHeight,
        d:             0,
        level:         1, // level = 1 for item, level = 2 for sub item
        childCount:    0
    });

    P.priv(container).onSelectedCallbacks.push(item.onSelected);
    return items.get(items.count - 1);
}

function addChildItem(parentItem, item) {
    if (parentItem === null || parentItem === undefined) return;

    var itemIndex = getItemIndex(parentItem);
    if (itemIndex < 0) return;

    var childCount = parentItem.childCount;
    var childIndex = itemIndex + childCount + 1;

    items.insert(childIndex, {
        name:      item.name,
        categoryKey: parentItem.categoryKey,
        category:  parentItem.category,
        isEnabled: item.isEnabled !== undefined ? item.isEnabled : true,
        image:     item.image !== undefined ? item.image : "",
        h:         item.h !== undefined ? item.h : 0,
        d:         0,
        level:     2,
        parent:    parentItem
    });

    parentItem.childCount++;
    internals.hasChildItems = true;

    var externalIndex = toExternalIndex(childIndex);
    P.priv(container).onSelectedCallbacks.splice(externalIndex, 0, item.onSelected);
}

// this is the main function to open/close a category. opens if open is true, closes if false.
function revealCategory(category, open) {
    if (open) {
        if (onlyOneCategoryCanBeOpen) {
            closeCategories();
        }
        openCategory(category);
    }
    else {
        closeCategory(category);
    }
}

//SR: item will be expanded and shown if it has children
function expandOrCollapseItem(index)
{
    if (index < 0 || index >= items.count)  return;
    if (getItemChildCount(index) < 1 ) return;

    if (isItemExpanded(index))
        showChildItems(index, false);
    else
        showChildItems(index, true);
}

function showChildItems(index, visible)
{
    var childCount = getItemChildCount(index);
    if (childCount < 1) return;

    var childIndex     = index + 1;
    var lastChildIndex = childIndex + childCount - 1;

    firstChildIndex = visible ? childIndex : -1;

    var count = 0;
    while (childIndex <= lastChildIndex)
    {
        var obj = items.get(childIndex++);
        if (obj) {
            obj.d = count++ * itemAnimationDuration;
            obj.h = (visible) ? itemHeight : 0;
        }
    }
}

function onRunningChangeHandler(running, index, delegateItem)
{
    if (!running)
    {
        if (!isItemVisible(delegateItem))
        {
            listView.positionViewAtIndex(index, listView.Visible);
        }
    }
}

function isItemVisible(delegateItem)
{
    if (delegateItem === undefined || delegateItem === null) return false;

    var contentY = listView.contentY;
    return ((delegateItem.y + itemHeight) <= (listView.height + contentY));
}

function computeIndex(obj)
{
    return listView.indexAt(obj.x + listView.contentX, obj.y + listView.contentY);
}

function isItemExpanded(index)
{
    var childCount = getItemChildCount(index);
    if (childCount < 1) return false;

    var childIndex = index + 1;
    var lastChildIndex = childIndex + childCount - 1;

    if (lastChildIndex < items.count) {
        return items.get(childIndex).h === itemHeight;
    }
    return false;
}

function getItemChildCount(index)
{
    if (index < 0 || index >= items.count) return 0;
    var count = (items.get(index).childCount !== undefined) ? items.get(index).childCount : 0;
    return count;
}

function getItemIndex(item)
{
    if (item === undefined || item === null) return -1;

    var length = items.count;
    for (var i = 0; i < length; i++) {
        if (item === items.get(i))
            return i;
    }
    return -1;
}

function expandParentIfNeeded(internalIndex)
{
    if (internalIndex < 0 || internalIndex >= items.count) return;

    var parentItem = items.get(internalIndex).parent;
    if (parentItem === undefined || parentItem === null) return;

    var parentIndex = getItemIndex(parentItem);

    if (!isItemExpanded(parentIndex))
    {
        if (parentIndex !== -1) {
            showChildItems(parentIndex, true);
        }
    }
}

//SR: Open category is done by setting some item height
// and start animation to display item
function openCategory(category)
{
    var count  = 0;
    for (var index = 0; index < items.count; ++index)
    {
        var obj = items.get(index);
        if (obj.categoryKey !== category) continue;

        // don't show child items
        if (obj.level !== 1) continue;

        obj.d = count++ * itemAnimationDuration;
        obj.h = itemHeight;
    }
}

function closeCategory(category)
{
    var count = 0;
    for (var index = items.count - 1; index >= 0; --index)
    {
        var obj = items.get(index);
        if (obj.categoryKey !== category) continue;

        //there may exists sub items which are already unvisible
        // so no need to process just to avoid unnecessary delay
        if (obj.h === 0) continue;

        obj.d = count++ * itemAnimationDuration;
        obj.h = 0;
    }
}

function scrollViewIfNeeded(index)
{
    var itemsShown =  Math.floor(listView.height / itemHeight);
    var shownCategoryCount = shownCategoriesCount(index);

    var elemIndex = (index + 1) + shownCategoryCount;

    if (elemIndex > itemsShown)
    {
        var displayedContentY = (elemIndex - itemsShown) * itemHeight;
        if (displayedContentY > listView.contentY)
            listView.contentY = displayedContentY;
    }
}

function shownCategoriesCount(index)
{
    var count = 0;
    if (index < 0 && index >= items.count) return count;

    var lastCategory = "";
    for (var k = 0; k < items.count; ++k)
    {
        var obj = items.get(k);
        if (obj.categoryKey !== lastCategory)
        {
            count++;
            lastCategory = obj.categoryKey;
        }
        if (k === index) break;
    }

    return count;
}

function closeCategories() {
    var count  = 0;
    for (var index = items.count - 1; index >= 0; --index)
    {
        var obj = items.get(index);
        obj.d = count++ * itemAnimationDuration;
        obj.h = 0;
    }
}

function isCategoryOpen(category)
{
    for (var i = 0; i < items.count; ++i) {
        var obj = items.get(i);
        if (obj.categoryKey === category && obj.h > 0) return true;
    }

    return false;
}

function numItemsWithCategory(category)
{
    var num = 0;
    for (var index = 0; index < items.count; ++index) {
        var obj = items.get(index);
        if (obj.categoryKey === category) ++num;
    }

    return num;
}

// returns the index of the Nth or last item in a section (category), based on the model.
// n = 1 corresponds to the first item in the section.
function indexOfNthItemInSection(n, category)
{
    var count = 0;
    var index = 0;

    for (var k = 0; k < items.count; ++k) {
        var obj = items.get(k);
        if (obj.categoryKey === category) {
            ++count;
            if (count <= n) index = k;
        }
    }
    return index;
}

function toInternalIndex(externalIndex)
{
    if (!internals.hasChildItems)
        return externalIndex;

    // only if tree has children
    var internalIndex = -1;
    for (var i = 0; i < items.count; i++) {
        if (items.get(i).level === 2)
            internalIndex++;

        if (internalIndex === externalIndex) {
            return i;
        }
    }
    return -1;
}

function toExternalIndex(internalIndex)
{
    if (!internals.hasChildItems)
        return internalIndex;

    var i = 0;
    var externalIndex = -1;
    var count = items.count;

    if (internalIndex < 0 || internalIndex >= count) return internalIndex;

    while (i <= internalIndex && i < count) {
        if (items.get(i).level === 2) {
            externalIndex++;
        }
        i++;
    }
    return externalIndex;
}

