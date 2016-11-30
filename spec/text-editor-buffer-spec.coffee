clipboard = require '../src/safe-clipboard'

describe "TextEditor buffer manipulation", ->
  [buffer, editor] = []

  convertToHardTabs = (buffer) ->
    buffer.setText(buffer.getText().replace(/[ ]{2}/g, "\t"))

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.js', {autoIndent: false}).then (o) -> editor = o

    runs ->
      buffer = editor.buffer
      editor.update({autoIndent: false})

    waitsForPromise ->
      atom.packages.activatePackage('language-javascript')

  afterEach ->
    editor.destroy()

  describe ".moveLineUp", ->
    it "moves the line under the cursor up", ->
      editor.setCursorBufferPosition([1, 0])
      editor.moveLineUp()
      expect(editor.getTextInBufferRange([[0, 0], [0, 30]])).toBe "  var sort = function(items) {"
      expect(editor.indentationForBufferRow(0)).toBe 1
      expect(editor.indentationForBufferRow(1)).toBe 0

    it "updates the line's indentation when the the autoIndent setting is true", ->
      editor.update({autoIndent: true})
      editor.setCursorBufferPosition([1, 0])
      editor.moveLineUp()
      expect(editor.indentationForBufferRow(0)).toBe 0
      expect(editor.indentationForBufferRow(1)).toBe 0

    describe "when there is a single selection", ->
      describe "when the selection spans a single line", ->
        describe "when there is no fold in the preceeding row", ->
          it "moves the line to the preceding row", ->
            expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
            expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

            editor.setSelectedBufferRange([[3, 2], [3, 9]])
            editor.moveLineUp()

            expect(editor.getSelectedBufferRange()).toEqual [[2, 2], [2, 9]]
            expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"

        describe "when the cursor is at the beginning of a fold", ->
          it "moves the line to the previous row without breaking the fold", ->
            expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

            editor.foldBufferRowRange(4, 7)
            editor.setSelectedBufferRange([[4, 2], [4, 9]], preserveFolds: true)
            expect(editor.getSelectedBufferRange()).toEqual [[4, 2], [4, 9]]

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.moveLineUp()

            expect(editor.getSelectedBufferRange()).toEqual [[3, 2], [3, 9]]
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(7)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()


        describe "when the preceding row consists of folded code", ->
          it "moves the line above the folded row and preseveres the correct folds", ->
            expect(editor.lineTextForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editor.lineTextForBufferRow(9)).toBe "  };"

            editor.foldBufferRowRange(4, 7)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.setSelectedBufferRange([[8, 0], [8, 4]])
            editor.moveLineUp()

            expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [4, 4]]
            expect(editor.lineTextForBufferRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

      describe "when the selection spans multiple lines", ->
        it "moves the lines spanned by the selection to the preceding row", ->
          expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.setSelectedBufferRange([[3, 2], [4, 9]])
          editor.moveLineUp()

          expect(editor.getSelectedBufferRange()).toEqual [[2, 2], [3, 9]]
          expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
          expect(editor.lineTextForBufferRow(4)).toBe "    if (items.length <= 1) return items;"

        describe "when the selection's end intersects a fold", ->
          it "moves the lines to the previous row without breaking the fold", ->
            expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

            editor.foldBufferRowRange(4, 7)
            editor.setSelectedBufferRange([[3, 2], [4, 9]], preserveFolds: true)

            expect(editor.isFoldedAtBufferRow(3)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.moveLineUp()

            expect(editor.getSelectedBufferRange()).toEqual [[2, 2], [3, 9]]
            expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(7)).toBe "    if (items.length <= 1) return items;"

            expect(editor.isFoldedAtBufferRow(2)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()

        describe "when the selection's start intersects a fold", ->
          it "moves the lines to the previous row without breaking the fold", ->
            expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

            editor.foldBufferRowRange(4, 7)
            editor.setSelectedBufferRange([[4, 2], [8, 9]], preserveFolds: true)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

            editor.moveLineUp()

            expect(editor.getSelectedBufferRange()).toEqual [[3, 2], [7, 9]]
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(7)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editor.lineTextForBufferRow(8)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()


      describe "when the selection spans multiple lines, but ends at column 0", ->
        it "does not move the last line of the selection", ->
          expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.setSelectedBufferRange([[3, 2], [4, 0]])
          editor.moveLineUp()

          expect(editor.getSelectedBufferRange()).toEqual [[2, 2], [3, 0]]
          expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

      describe "when the preceeding row is a folded row", ->
        it "moves the lines spanned by the selection to the preceeding row, but preserves the folded code", ->
          expect(editor.lineTextForBufferRow(8)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
          expect(editor.lineTextForBufferRow(9)).toBe "  };"

          editor.foldBufferRowRange(4, 7)
          expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

          editor.setSelectedBufferRange([[8, 0], [9, 2]])
          editor.moveLineUp()

          expect(editor.getSelectedBufferRange()).toEqual [[4, 0], [5, 2]]
          expect(editor.lineTextForBufferRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
          expect(editor.lineTextForBufferRow(5)).toBe "  };"
          expect(editor.lineTextForBufferRow(6)).toBe "    while(items.length > 0) {"
          expect(editor.isFoldedAtBufferRow(5)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(9)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(10)).toBeFalsy()

    describe "when there are multiple selections", ->
      describe "when all the selections span different lines", ->
        describe "when there is no folds", ->
          it "moves all lines that are spanned by a selection to the preceding row", ->
            editor.setSelectedBufferRanges([[[1, 2], [1, 9]], [[3, 2], [3, 9]], [[5, 2], [5, 9]]])
            editor.moveLineUp()

            expect(editor.getSelectedBufferRanges()).toEqual [[[0, 2], [0, 9]], [[2, 2], [2, 9]], [[4, 2], [4, 9]]]
            expect(editor.lineTextForBufferRow(0)).toBe "  var sort = function(items) {"
            expect(editor.lineTextForBufferRow(1)).toBe "var quicksort = function () {"
            expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"
            expect(editor.lineTextForBufferRow(4)).toBe "      current = items.shift();"
            expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"

        describe "when one selection intersects a fold", ->
          it "moves the lines to the previous row without breaking the fold", ->
            expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

            editor.foldBufferRowRange(4, 7)
            editor.setSelectedBufferRanges([
              [[2, 2], [2, 9]],
              [[4, 2], [4, 9]]
            ], preserveFolds: true)

            expect(editor.isFoldedAtBufferRow(2)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(3)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

            editor.moveLineUp()

            expect(editor.getSelectedBufferRanges()).toEqual([
              [[1, 2], [1, 9]],
              [[3, 2], [3, 9]]
            ])

            expect(editor.lineTextForBufferRow(1)).toBe "    if (items.length <= 1) return items;"
            expect(editor.lineTextForBufferRow(2)).toBe "  var sort = function(items) {"
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(7)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

            expect(editor.isFoldedAtBufferRow(1)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(2)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

        describe "when there is a fold", ->
          it "moves all lines that spanned by a selection to preceding row, preserving all folds", ->
            editor.foldBufferRowRange(4, 7)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.setSelectedBufferRanges([[[8, 0], [8, 3]], [[11, 0], [11, 5]]])
            editor.moveLineUp()

            expect(editor.getSelectedBufferRanges()).toEqual [[[4, 0], [4, 3]], [[10, 0], [10, 5]]]
            expect(editor.lineTextForBufferRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editor.lineTextForBufferRow(10)).toBe "  return sort(Array.apply(this, arguments));"
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

      describe 'when there are many folds', ->
        beforeEach ->
          waitsForPromise ->
            atom.workspace.open('sample-with-many-folds.js', autoIndent: false).then (o) -> editor = o

        describe 'and many selections intersects folded rows', ->
          it 'moves and preserves all the folds', ->
            editor.foldBufferRowRange(2, 4)
            editor.foldBufferRowRange(7, 9)

            editor.setSelectedBufferRanges([
              [[1, 0], [5, 4]],
              [[7, 0], [7, 4]]
            ], preserveFolds: true)

            editor.moveLineUp()

            expect(editor.lineTextForBufferRow(1)).toEqual "function f3() {"
            expect(editor.lineTextForBufferRow(4)).toEqual "6;"
            expect(editor.lineTextForBufferRow(5)).toEqual "1;"
            expect(editor.lineTextForBufferRow(6)).toEqual "function f8() {"
            expect(editor.lineTextForBufferRow(9)).toEqual "7;"

            expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(2)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeFalsy()

            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

      describe "when some of the selections span the same lines", ->
        it "moves lines that contain multiple selections correctly", ->
          editor.setSelectedBufferRanges([[[3, 2], [3, 9]], [[3, 12], [3, 13]]])
          editor.moveLineUp()

          expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [2, 9]], [[2, 12], [2, 13]]]
          expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

      describe "when one of the selections spans line 0", ->
        it "doesn't move any lines, since line 0 can't move", ->
          editor.setSelectedBufferRanges([[[0, 2], [1, 9]], [[2, 2], [2, 9]], [[4, 2], [4, 9]]])

          editor.moveLineUp()

          expect(editor.getSelectedBufferRanges()).toEqual [[[0, 2], [1, 9]], [[2, 2], [2, 9]], [[4, 2], [4, 9]]]
          expect(buffer.isModified()).toBe false

      describe "when one of the selections spans the last line, and it is empty", ->
        it "doesn't move any lines, since the last line can't move", ->
          buffer.append('\n')
          editor.setSelectedBufferRanges([[[0, 2], [1, 9]], [[2, 2], [2, 9]], [[13, 0], [13, 0]]])

          editor.moveLineUp()

          expect(editor.getSelectedBufferRanges()).toEqual [[[0, 2], [1, 9]], [[2, 2], [2, 9]], [[13, 0], [13, 0]]]

  describe ".moveLineDown", ->
    it "moves the line under the cursor down", ->
      editor.setCursorBufferPosition([0, 0])
      editor.moveLineDown()
      expect(editor.getTextInBufferRange([[1, 0], [1, 31]])).toBe "var quicksort = function () {"
      expect(editor.indentationForBufferRow(0)).toBe 1
      expect(editor.indentationForBufferRow(1)).toBe 0

    it "updates the line's indentation when the editor.autoIndent setting is true", ->
      editor.update({autoIndent: true})
      editor.setCursorBufferPosition([0, 0])
      editor.moveLineDown()
      expect(editor.indentationForBufferRow(0)).toBe 1
      expect(editor.indentationForBufferRow(1)).toBe 2

    describe "when there is a single selection", ->
      describe "when the selection spans a single line", ->
        describe "when there is no fold in the following row", ->
          it "moves the line to the following row", ->
            expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
            expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

            editor.setSelectedBufferRange([[2, 2], [2, 9]])
            editor.moveLineDown()

            expect(editor.getSelectedBufferRange()).toEqual [[3, 2], [3, 9]]
            expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"

        describe "when the cursor is at the beginning of a fold", ->
          it "moves the line to the following row without breaking the fold", ->
            expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

            editor.foldBufferRowRange(4, 7)
            editor.setSelectedBufferRange([[4, 2], [4, 9]], preserveFolds: true)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.moveLineDown()

            expect(editor.getSelectedBufferRange()).toEqual [[5, 2], [5, 9]]
            expect(editor.lineTextForBufferRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
            expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"

            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

        describe "when the following row is a folded row", ->
          it "moves the line below the folded row and preserves the fold", ->
            expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

            editor.foldBufferRowRange(4, 7)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.setSelectedBufferRange([[3, 0], [3, 4]])
            editor.moveLineDown()

            expect(editor.getSelectedBufferRange()).toEqual [[7, 0], [7, 4]]
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()


            expect(editor.lineTextForBufferRow(7)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

      describe "when the selection spans multiple lines", ->
        it "moves the lines spanned by the selection to the following row", ->
          expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.setSelectedBufferRange([[2, 2], [3, 9]])
          editor.moveLineDown()

          expect(editor.getSelectedBufferRange()).toEqual [[3, 2], [4, 9]]
          expect(editor.lineTextForBufferRow(2)).toBe "    while(items.length > 0) {"
          expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

      describe "when the selection spans multiple lines, but ends at column 0", ->
        it "does not move the last line of the selection", ->
          expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.setSelectedBufferRange([[2, 2], [3, 0]])
          editor.moveLineDown()

          expect(editor.getSelectedBufferRange()).toEqual [[3, 2], [4, 0]]
          expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

      describe "when the selection's end intersects a fold", ->
        it "moves the lines to the following row without breaking the fold", ->
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.foldBufferRowRange(4, 7)
          editor.setSelectedBufferRange([[3, 2], [4, 9]], preserveFolds: true)

          expect(editor.isFoldedAtBufferRow(3)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

          editor.moveLineDown()

          expect(editor.getSelectedBufferRange()).toEqual [[4, 2], [5, 9]]
          expect(editor.lineTextForBufferRow(3)).toBe "    return sort(left).concat(pivot).concat(sort(right));"
          expect(editor.lineTextForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"

          expect(editor.isFoldedAtBufferRow(4)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

      describe "when the selection's start intersects a fold", ->
        it "moves the lines to the following row without breaking the fold", ->
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.foldBufferRowRange(4, 7)
          editor.setSelectedBufferRange([[4, 2], [8, 9]], preserveFolds: true)

          expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

          editor.moveLineDown()

          expect(editor.getSelectedBufferRange()).toEqual [[5, 2], [9, 9]]
          expect(editor.lineTextForBufferRow(4)).toBe "  };"
          expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"
          expect(editor.lineTextForBufferRow(9)).toBe "    return sort(left).concat(pivot).concat(sort(right));"

          expect(editor.isFoldedAtBufferRow(4)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(10)).toBeFalsy()

      describe "when the following row is a folded row", ->
        it "moves the lines spanned by the selection to the following row, but preserves the folded code", ->
          expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

          editor.foldBufferRowRange(4, 7)
          expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

          editor.setSelectedBufferRange([[2, 0], [3, 2]])
          editor.moveLineDown()

          expect(editor.getSelectedBufferRange()).toEqual [[6, 0], [7, 2]]
          expect(editor.lineTextForBufferRow(2)).toBe "    while(items.length > 0) {"
          expect(editor.isFoldedAtBufferRow(1)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(2)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeFalsy()
          expect(editor.lineTextForBufferRow(6)).toBe "    if (items.length <= 1) return items;"

    describe "when there are multiple selections", ->
      describe "when all the selections span different lines", ->
        describe "when there is no folds", ->
          it "moves all lines that are spanned by a selection to the following row", ->
            editor.setSelectedBufferRanges([[[1, 2], [1, 9]], [[3, 2], [3, 9]], [[5, 2], [5, 9]]])
            editor.moveLineDown()

            expect(editor.getSelectedBufferRanges()).toEqual [[[6, 2], [6, 9]], [[4, 2], [4, 9]], [[2, 2], [2, 9]]]
            expect(editor.lineTextForBufferRow(1)).toBe "    if (items.length <= 1) return items;"
            expect(editor.lineTextForBufferRow(2)).toBe "  var sort = function(items) {"
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(5)).toBe "      current < pivot ? left.push(current) : right.push(current);"
            expect(editor.lineTextForBufferRow(6)).toBe "      current = items.shift();"

        describe 'when there are many folds', ->
          beforeEach ->
            waitsForPromise ->
              atom.workspace.open('sample-with-many-folds.js', autoIndent: false).then (o) -> editor = o

          describe 'and many selections intersects folded rows', ->
            it 'moves and preserves all the folds', ->
              editor.foldBufferRowRange(2, 4)
              editor.foldBufferRowRange(7, 9)

              editor.setSelectedBufferRanges([
                [[2, 0], [2, 4]],
                [[6, 0], [10, 4]]
              ], preserveFolds: true)

              editor.moveLineDown()

              expect(editor.lineTextForBufferRow(2)).toEqual "6;"
              expect(editor.lineTextForBufferRow(3)).toEqual "function f3() {"
              expect(editor.lineTextForBufferRow(6)).toEqual "12;"
              expect(editor.lineTextForBufferRow(7)).toEqual "7;"
              expect(editor.lineTextForBufferRow(8)).toEqual "function f8() {"
              expect(editor.lineTextForBufferRow(11)).toEqual "11;"

              expect(editor.isFoldedAtBufferRow(2)).toBeFalsy()
              expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
              expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
              expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
              expect(editor.isFoldedAtBufferRow(6)).toBeFalsy()
              expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()
              expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
              expect(editor.isFoldedAtBufferRow(9)).toBeTruthy()
              expect(editor.isFoldedAtBufferRow(10)).toBeTruthy()
              expect(editor.isFoldedAtBufferRow(11)).toBeFalsy()

        describe "when there is a fold below one of the selected row", ->
          it "moves all lines spanned by a selection to the following row, preserving the fold", ->
            editor.foldBufferRowRange(4, 7)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.setSelectedBufferRanges([[[1, 2], [1, 6]], [[3, 0], [3, 4]], [[8, 0], [8, 3]]])
            editor.moveLineDown()

            expect(editor.getSelectedBufferRanges()).toEqual [[[9, 0], [9, 3]], [[7, 0], [7, 4]], [[2, 2], [2, 6]]]
            expect(editor.lineTextForBufferRow(2)).toBe "  var sort = function(items) {"
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeFalsy()
            expect(editor.lineTextForBufferRow(7)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(9)).toBe "    return sort(left).concat(pivot).concat(sort(right));"

        describe "when there is a fold below a group of multiple selections without any lines with no selection in-between", ->
          it "moves all the lines below the fold, preserving the fold", ->
            editor.foldBufferRowRange(4, 7)

            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()

            editor.setSelectedBufferRanges([[[2, 2], [2, 6]], [[3, 0], [3, 4]]])
            editor.moveLineDown()

            expect(editor.getSelectedBufferRanges()).toEqual [[[7, 0], [7, 4]], [[6, 2], [6, 6]]]
            expect(editor.lineTextForBufferRow(2)).toBe "    while(items.length > 0) {"
            expect(editor.isFoldedAtBufferRow(2)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(3)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
            expect(editor.isFoldedAtBufferRow(6)).toBeFalsy()
            expect(editor.lineTextForBufferRow(6)).toBe "    if (items.length <= 1) return items;"
            expect(editor.lineTextForBufferRow(7)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

      describe "when one selection intersects a fold", ->
        it "moves the lines to the previous row without breaking the fold", ->
          expect(editor.lineTextForBufferRow(4)).toBe "    while(items.length > 0) {"

          editor.foldBufferRowRange(4, 7)
          editor.setSelectedBufferRanges([
            [[2, 2], [2, 9]],
            [[4, 2], [4, 9]]
          ], preserveFolds: true)

          expect(editor.isFoldedAtBufferRow(2)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(3)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

          editor.moveLineDown()

          expect(editor.getSelectedBufferRanges()).toEqual([
            [[5, 2], [5, 9]]
            [[3, 2], [3, 9]],
          ])

          expect(editor.lineTextForBufferRow(2)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(3)).toBe "    if (items.length <= 1) return items;"
          expect(editor.lineTextForBufferRow(4)).toBe "    return sort(left).concat(pivot).concat(sort(right));"

          expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"
          expect(editor.lineTextForBufferRow(9)).toBe "  };"

          expect(editor.isFoldedAtBufferRow(2)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(3)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(4)).toBeFalsy()
          expect(editor.isFoldedAtBufferRow(5)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(7)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(8)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(9)).toBeFalsy()

      describe "when some of the selections span the same lines", ->
        it "moves lines that contain multiple selections correctly", ->
          editor.setSelectedBufferRanges([[[3, 2], [3, 9]], [[3, 12], [3, 13]]])
          editor.moveLineDown()

          expect(editor.getSelectedBufferRanges()).toEqual [[[4, 12], [4, 13]], [[4, 2], [4, 9]]]
          expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"

      describe "when the selections are above a wrapped line", ->
        beforeEach ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(80)
          editor.setText("""
          1
          2
          Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequat.
          3
          4
          """)

        it 'moves the lines past the soft wrapped line', ->
          editor.setSelectedBufferRanges([[[0, 0], [0, 0]], [[1, 0], [1, 0]]])

          editor.moveLineDown()

          expect(editor.lineTextForBufferRow(0)).not.toBe "2"
          expect(editor.lineTextForBufferRow(1)).toBe "1"
          expect(editor.lineTextForBufferRow(2)).toBe "2"

    describe "when the line is the last buffer row", ->
      it "doesn't move it", ->
        editor.setText("abc\ndef")
        editor.setCursorBufferPosition([1, 0])
        editor.moveLineDown()
        expect(editor.getText()).toBe("abc\ndef")

  describe ".insertText(text)", ->
    describe "when there is a single selection", ->
      beforeEach ->
        editor.setSelectedBufferRange([[1, 0], [1, 2]])

      it "replaces the selection with the given text", ->
        range = editor.insertText('xxx')
        expect(range).toEqual [ [[1, 0], [1, 3]] ]
        expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'

    describe "when there are multiple empty selections", ->
      describe "when the cursors are on the same line", ->
        it "inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", ->
          editor.setCursorScreenPosition([1, 2])
          editor.addCursorAtScreenPosition([1, 5])

          editor.insertText('xxx')

          expect(buffer.lineForRow(1)).toBe '  xxxvarxxx sort = function(items) {'
          [cursor1, cursor2] = editor.getCursors()

          expect(cursor1.getBufferPosition()).toEqual [1, 5]
          expect(cursor2.getBufferPosition()).toEqual [1, 11]

      describe "when the cursors are on different lines", ->
        it "inserts the given text at the location of each cursor and moves the cursors to the end of each cursor's inserted text", ->
          editor.setCursorScreenPosition([1, 2])
          editor.addCursorAtScreenPosition([2, 4])

          editor.insertText('xxx')

          expect(buffer.lineForRow(1)).toBe '  xxxvar sort = function(items) {'
          expect(buffer.lineForRow(2)).toBe '    xxxif (items.length <= 1) return items;'
          [cursor1, cursor2] = editor.getCursors()

          expect(cursor1.getBufferPosition()).toEqual [1, 5]
          expect(cursor2.getBufferPosition()).toEqual [2, 7]

    describe "when there are multiple non-empty selections", ->
      describe "when the selections are on the same line", ->
        it "replaces each selection range with the inserted characters", ->
          editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 22], [0, 24]]])
          editor.insertText("x")

          [cursor1, cursor2] = editor.getCursors()
          [selection1, selection2] = editor.getSelections()

          expect(cursor1.getScreenPosition()).toEqual [0, 5]
          expect(cursor2.getScreenPosition()).toEqual [0, 15]
          expect(selection1.isEmpty()).toBeTruthy()
          expect(selection2.isEmpty()).toBeTruthy()

          expect(editor.lineTextForBufferRow(0)).toBe "var x = functix () {"

      describe "when the selections are on different lines", ->
        it "replaces each selection with the given text, clears the selections, and places the cursor at the end of each selection's inserted text", ->
          editor.setSelectedBufferRanges([[[1, 0], [1, 2]], [[2, 0], [2, 4]]])

          editor.insertText('xxx')

          expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'
          expect(buffer.lineForRow(2)).toBe 'xxxif (items.length <= 1) return items;'
          [selection1, selection2] = editor.getSelections()

          expect(selection1.isEmpty()).toBeTruthy()
          expect(selection1.cursor.getBufferPosition()).toEqual [1, 3]
          expect(selection2.isEmpty()).toBeTruthy()
          expect(selection2.cursor.getBufferPosition()).toEqual [2, 3]

    describe "when there is a selection that ends on a folded line", ->
      it "destroys the selection", ->
        editor.foldBufferRowRange(2, 4)
        editor.setSelectedBufferRange([[1, 0], [2, 0]])
        editor.insertText('holy cow')
        expect(editor.isFoldedAtScreenRow(2)).toBeFalsy()

    describe "when there are ::onWillInsertText and ::onDidInsertText observers", ->
      beforeEach ->
        editor.setSelectedBufferRange([[1, 0], [1, 2]])

      it "notifies the observers when inserting text", ->
        willInsertSpy = jasmine.createSpy().andCallFake ->
          expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'

        didInsertSpy = jasmine.createSpy().andCallFake ->
          expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'

        editor.onWillInsertText(willInsertSpy)
        editor.onDidInsertText(didInsertSpy)

        expect(editor.insertText('xxx')).toBeTruthy()
        expect(buffer.lineForRow(1)).toBe 'xxxvar sort = function(items) {'

        expect(willInsertSpy).toHaveBeenCalled()
        expect(didInsertSpy).toHaveBeenCalled()

        options = willInsertSpy.mostRecentCall.args[0]
        expect(options.text).toBe 'xxx'
        expect(options.cancel).toBeDefined()

        options = didInsertSpy.mostRecentCall.args[0]
        expect(options.text).toBe 'xxx'

      it "cancels text insertion when an ::onWillInsertText observer calls cancel on an event", ->
        willInsertSpy = jasmine.createSpy().andCallFake ({cancel}) ->
          cancel()

        didInsertSpy = jasmine.createSpy()

        editor.onWillInsertText(willInsertSpy)
        editor.onDidInsertText(didInsertSpy)

        expect(editor.insertText('xxx')).toBe false
        expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {'

        expect(willInsertSpy).toHaveBeenCalled()
        expect(didInsertSpy).not.toHaveBeenCalled()

    describe "when the undo option is set to 'skip'", ->
      beforeEach ->
        editor.setSelectedBufferRange([[1, 2], [1, 2]])

      it "does not undo the skipped operation", ->
        range = editor.insertText('x')
        range = editor.insertText('y', undo: 'skip')
        editor.undo()
        expect(buffer.lineForRow(1)).toBe '  yvar sort = function(items) {'

  describe ".insertNewline()", ->
    describe "when there is a single cursor", ->
      describe "when the cursor is at the beginning of a line", ->
        it "inserts an empty line before it", ->
          editor.setCursorScreenPosition(row: 1, column: 0)

          editor.insertNewline()

          expect(buffer.lineForRow(1)).toBe ''
          expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

      describe "when the cursor is in the middle of a line", ->
        it "splits the current line to form a new line", ->
          editor.setCursorScreenPosition(row: 1, column: 6)
          originalLine = buffer.lineForRow(1)
          lineBelowOriginalLine = buffer.lineForRow(2)

          editor.insertNewline()

          expect(buffer.lineForRow(1)).toBe originalLine[0...6]
          expect(buffer.lineForRow(2)).toBe originalLine[6..]
          expect(buffer.lineForRow(3)).toBe lineBelowOriginalLine
          expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

      describe "when the cursor is on the end of a line", ->
        it "inserts an empty line after it", ->
          editor.setCursorScreenPosition(row: 1, column: buffer.lineForRow(1).length)

          editor.insertNewline()

          expect(buffer.lineForRow(2)).toBe ''
          expect(editor.getCursorScreenPosition()).toEqual(row: 2, column: 0)

    describe "when there are multiple cursors", ->
      describe "when the cursors are on the same line", ->
        it "breaks the line at the cursor locations", ->
          editor.setCursorScreenPosition([3, 13])
          editor.addCursorAtScreenPosition([3, 38])

          editor.insertNewline()

          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot"
          expect(editor.lineTextForBufferRow(4)).toBe " = items.shift(), current"
          expect(editor.lineTextForBufferRow(5)).toBe ", left = [], right = [];"
          expect(editor.lineTextForBufferRow(6)).toBe "    while(items.length > 0) {"

          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [4, 0]
          expect(cursor2.getBufferPosition()).toEqual [5, 0]

      describe "when the cursors are on different lines", ->
        it "inserts newlines at each cursor location", ->
          editor.setCursorScreenPosition([3, 0])
          editor.addCursorAtScreenPosition([6, 0])

          editor.insertText("\n")
          expect(editor.lineTextForBufferRow(3)).toBe ""
          expect(editor.lineTextForBufferRow(4)).toBe "    var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.lineTextForBufferRow(5)).toBe "    while(items.length > 0) {"
          expect(editor.lineTextForBufferRow(6)).toBe "      current = items.shift();"
          expect(editor.lineTextForBufferRow(7)).toBe ""
          expect(editor.lineTextForBufferRow(8)).toBe "      current < pivot ? left.push(current) : right.push(current);"
          expect(editor.lineTextForBufferRow(9)).toBe "    }"

          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [4, 0]
          expect(cursor2.getBufferPosition()).toEqual [8, 0]

  describe ".insertNewlineBelow()", ->
    describe "when the operation is undone", ->
      it "places the cursor back at the previous location", ->
        editor.setCursorBufferPosition([0, 2])
        editor.insertNewlineBelow()
        expect(editor.getCursorBufferPosition()).toEqual [1, 0]
        editor.undo()
        expect(editor.getCursorBufferPosition()).toEqual [0, 2]

    it "inserts a newline below the cursor's current line, autoindents it, and moves the cursor to the end of the line", ->
      editor.update({autoIndent: true})
      editor.insertNewlineBelow()
      expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
      expect(buffer.lineForRow(1)).toBe "  "
      expect(editor.getCursorBufferPosition()).toEqual [1, 2]

  describe ".insertNewlineAbove()", ->
    describe "when the cursor is on first line", ->
      it "inserts a newline on the first line and moves the cursor to the first line", ->
        editor.setCursorBufferPosition([0])
        editor.insertNewlineAbove()
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]
        expect(editor.lineTextForBufferRow(0)).toBe ''
        expect(editor.lineTextForBufferRow(1)).toBe 'var quicksort = function () {'
        expect(editor.buffer.getLineCount()).toBe 14

    describe "when the cursor is not on the first line", ->
      it "inserts a newline above the current line and moves the cursor to the inserted line", ->
        editor.setCursorBufferPosition([3, 4])
        editor.insertNewlineAbove()
        expect(editor.getCursorBufferPosition()).toEqual [3, 0]
        expect(editor.lineTextForBufferRow(3)).toBe ''
        expect(editor.lineTextForBufferRow(4)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
        expect(editor.buffer.getLineCount()).toBe 14

        editor.undo()
        expect(editor.getCursorBufferPosition()).toEqual [3, 4]

    it "indents the new line to the correct level when editor.autoIndent is true", ->
      editor.update({autoIndent: true})

      editor.setText('  var test')
      editor.setCursorBufferPosition([0, 2])
      editor.insertNewlineAbove()

      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      expect(editor.lineTextForBufferRow(0)).toBe '  '
      expect(editor.lineTextForBufferRow(1)).toBe '  var test'

      editor.setText('\n  var test')
      editor.setCursorBufferPosition([1, 2])
      editor.insertNewlineAbove()

      expect(editor.getCursorBufferPosition()).toEqual [1, 2]
      expect(editor.lineTextForBufferRow(0)).toBe ''
      expect(editor.lineTextForBufferRow(1)).toBe '  '
      expect(editor.lineTextForBufferRow(2)).toBe '  var test'

      editor.setText('function() {\n}')
      editor.setCursorBufferPosition([1, 1])
      editor.insertNewlineAbove()

      expect(editor.getCursorBufferPosition()).toEqual [1, 2]
      expect(editor.lineTextForBufferRow(0)).toBe 'function() {'
      expect(editor.lineTextForBufferRow(1)).toBe '  '
      expect(editor.lineTextForBufferRow(2)).toBe '}'

  describe ".insertNewLine()", ->
    describe "when a new line is appended before a closing tag (e.g. by pressing enter before a selection)", ->
      it "moves the line down and keeps the indentation level the same when editor.autoIndent is true", ->
        editor.update({autoIndent: true})
        editor.setCursorBufferPosition([9, 2])
        editor.insertNewline()
        expect(editor.lineTextForBufferRow(10)).toBe '  };'

    describe "when a newline is appended with a trailing closing tag behind the cursor (e.g. by pressing enter in the middel of a line)", ->
      it "indents the new line to the correct level when editor.autoIndent is true and using a curly-bracket language", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-javascript')

        runs ->
          editor.update({autoIndent: true})
          editor.setGrammar(atom.grammars.selectGrammar("file.js"))
          editor.setText('var test = function () {\n  return true;};')
          editor.setCursorBufferPosition([1, 14])
          editor.insertNewline()
          expect(editor.indentationForBufferRow(1)).toBe 1
          expect(editor.indentationForBufferRow(2)).toBe 0

      it "indents the new line to the current level when editor.autoIndent is true and no increaseIndentPattern is specified", ->
        runs ->
          editor.setGrammar(atom.grammars.selectGrammar("file"))
          editor.update({autoIndent: true})
          editor.setText('  if true')
          editor.setCursorBufferPosition([0, 8])
          editor.insertNewline()
          expect(editor.getGrammar()).toBe atom.grammars.nullGrammar
          expect(editor.indentationForBufferRow(0)).toBe 1
          expect(editor.indentationForBufferRow(1)).toBe 1

      it "indents the new line to the correct level when editor.autoIndent is true and using an off-side rule language", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-coffee-script')

        runs ->
          editor.update({autoIndent: true})
          editor.setGrammar(atom.grammars.selectGrammar("file.coffee"))
          editor.setText('if true\n  return trueelse\n  return false')
          editor.setCursorBufferPosition([1, 13])
          editor.insertNewline()
          expect(editor.indentationForBufferRow(1)).toBe 1
          expect(editor.indentationForBufferRow(2)).toBe 0
          expect(editor.indentationForBufferRow(3)).toBe 1

    describe "when a newline is appended on a line that matches the decreaseNextIndentPattern", ->
      it "indents the new line to the correct level when editor.autoIndent is true", ->
        waitsForPromise ->
          atom.packages.activatePackage('language-go')

        runs ->
          editor.update({autoIndent: true})
          editor.setGrammar(atom.grammars.selectGrammar("file.go"))
          editor.setText('fmt.Printf("some%s",\n	"thing")')
          editor.setCursorBufferPosition([1, 10])
          editor.insertNewline()
          expect(editor.indentationForBufferRow(1)).toBe 1
          expect(editor.indentationForBufferRow(2)).toBe 0

  describe ".backspace()", ->
    describe "when there is a single cursor", ->
      changeScreenRangeHandler = null

      beforeEach ->
        selection = editor.getLastSelection()
        changeScreenRangeHandler = jasmine.createSpy('changeScreenRangeHandler')
        selection.onDidChangeRange changeScreenRangeHandler

      describe "when the cursor is on the middle of the line", ->
        it "removes the character before the cursor", ->
          editor.setCursorScreenPosition(row: 1, column: 7)
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

          editor.backspace()

          line = buffer.lineForRow(1)
          expect(line).toBe "  var ort = function(items) {"
          expect(editor.getCursorScreenPosition()).toEqual {row: 1, column: 6}
          expect(changeScreenRangeHandler).toHaveBeenCalled()
          expect(editor.getLastCursor().isVisible()).toBeTruthy()

      describe "when the cursor is at the beginning of a line", ->
        it "joins it with the line above", ->
          originalLine0 = buffer.lineForRow(0)
          expect(originalLine0).toBe "var quicksort = function () {"
          expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"

          editor.setCursorScreenPosition(row: 1, column: 0)
          editor.backspace()

          line0 = buffer.lineForRow(0)
          line1 = buffer.lineForRow(1)
          expect(line0).toBe "var quicksort = function () {  var sort = function(items) {"
          expect(line1).toBe "    if (items.length <= 1) return items;"
          expect(editor.getCursorScreenPosition()).toEqual [0, originalLine0.length]

          expect(changeScreenRangeHandler).toHaveBeenCalled()

      describe "when the cursor is at the first column of the first line", ->
        it "does nothing, but doesn't raise an error", ->
          editor.setCursorScreenPosition(row: 0, column: 0)
          editor.backspace()

      describe "when the cursor is after a fold", ->
        it "deletes the folded range", ->
          editor.foldBufferRange([[4, 7], [5, 8]])
          editor.setCursorBufferPosition([5, 8])
          editor.backspace()

          expect(buffer.lineForRow(4)).toBe "    whirrent = items.shift();"
          expect(editor.isFoldedAtBufferRow(4)).toBe(false)

      describe "when the cursor is in the middle of a line below a fold", ->
        it "backspaces as normal", ->
          editor.setCursorScreenPosition([4, 0])
          editor.foldCurrentRow()
          editor.setCursorScreenPosition([5, 5])
          editor.backspace()

          expect(buffer.lineForRow(7)).toBe "    }"
          expect(buffer.lineForRow(8)).toBe "    eturn sort(left).concat(pivot).concat(sort(right));"

      describe "when the cursor is on a folded screen line", ->
        it "deletes the contents of the fold before the cursor", ->
          editor.setCursorBufferPosition([3, 0])
          editor.foldCurrentRow()
          editor.backspace()

          expect(buffer.lineForRow(1)).toBe "  var sort = function(items)     var pivot = items.shift(), current, left = [], right = [];"
          expect(editor.getCursorScreenPosition()).toEqual [1, 29]

    describe "when there are multiple cursors", ->
      describe "when cursors are on the same line", ->
        it "removes the characters preceding each cursor", ->
          editor.setCursorScreenPosition([3, 13])
          editor.addCursorAtScreenPosition([3, 38])

          editor.backspace()

          expect(editor.lineTextForBufferRow(3)).toBe "    var pivo = items.shift(), curren, left = [], right = [];"

          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [3, 12]
          expect(cursor2.getBufferPosition()).toEqual [3, 36]

          [selection1, selection2] = editor.getSelections()
          expect(selection1.isEmpty()).toBeTruthy()
          expect(selection2.isEmpty()).toBeTruthy()

      describe "when cursors are on different lines", ->
        describe "when the cursors are in the middle of their lines", ->
          it "removes the characters preceding each cursor", ->
            editor.setCursorScreenPosition([3, 13])
            editor.addCursorAtScreenPosition([4, 10])

            editor.backspace()

            expect(editor.lineTextForBufferRow(3)).toBe "    var pivo = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(4)).toBe "    whileitems.length > 0) {"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3, 12]
            expect(cursor2.getBufferPosition()).toEqual [4, 9]

            [selection1, selection2] = editor.getSelections()
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

        describe "when the cursors are on the first column of their lines", ->
          it "removes the newlines preceding each cursor", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addCursorAtScreenPosition([6, 0])

            editor.backspace()
            expect(editor.lineTextForBufferRow(2)).toBe "    if (items.length <= 1) return items;    var pivot = items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(3)).toBe "    while(items.length > 0) {"
            expect(editor.lineTextForBufferRow(4)).toBe "      current = items.shift();      current < pivot ? left.push(current) : right.push(current);"
            expect(editor.lineTextForBufferRow(5)).toBe "    }"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [2, 40]
            expect(cursor2.getBufferPosition()).toEqual [4, 30]

    describe "when there is a single selection", ->
      it "deletes the selection, but not the character before it", ->
        editor.setSelectedBufferRange([[0, 5], [0, 9]])
        editor.backspace()
        expect(editor.buffer.lineForRow(0)).toBe 'var qsort = function () {'

      describe "when the selection ends on a folded line", ->
        it "preserves the fold", ->
          editor.setSelectedBufferRange([[3, 0], [4, 0]])
          editor.foldBufferRow(4)
          editor.backspace()

          expect(buffer.lineForRow(3)).toBe "    while(items.length > 0) {"
          expect(editor.isFoldedAtScreenRow(3)).toBe(true)

    describe "when there are multiple selections", ->
      it "removes all selected text", ->
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 16], [0, 24]]])
        editor.backspace()
        expect(editor.lineTextForBufferRow(0)).toBe 'var  =  () {'

  describe ".deleteToPreviousWordBoundary()", ->
    describe "when no text is selected", ->
      it "deletes to the previous word boundary", ->
        editor.setCursorBufferPosition([0, 16])
        editor.addCursorAtBufferPosition([1, 21])
        [cursor1, cursor2] = editor.getCursors()

        editor.deleteToPreviousWordBoundary()
        expect(buffer.lineForRow(0)).toBe 'var quicksort =function () {'
        expect(buffer.lineForRow(1)).toBe '  var sort = (items) {'
        expect(cursor1.getBufferPosition()).toEqual [0, 15]
        expect(cursor2.getBufferPosition()).toEqual [1, 13]

        editor.deleteToPreviousWordBoundary()
        expect(buffer.lineForRow(0)).toBe 'var quicksort function () {'
        expect(buffer.lineForRow(1)).toBe '  var sort =(items) {'
        expect(cursor1.getBufferPosition()).toEqual [0, 14]
        expect(cursor2.getBufferPosition()).toEqual [1, 12]

    describe "when text is selected", ->
      it "deletes only selected text", ->
        editor.setSelectedBufferRange([[1, 24], [1, 27]])
        editor.deleteToPreviousWordBoundary()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'

  describe ".deleteToNextWordBoundary()", ->
    describe "when no text is selected", ->
      it "deletes to the next word boundary", ->
        editor.setCursorBufferPosition([0, 15])
        editor.addCursorAtBufferPosition([1, 24])
        [cursor1, cursor2] = editor.getCursors()

        editor.deleteToNextWordBoundary()
        expect(buffer.lineForRow(0)).toBe 'var quicksort =function () {'
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
        expect(cursor1.getBufferPosition()).toEqual [0, 15]
        expect(cursor2.getBufferPosition()).toEqual [1, 24]

        editor.deleteToNextWordBoundary()
        expect(buffer.lineForRow(0)).toBe 'var quicksort = () {'
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it {'
        expect(cursor1.getBufferPosition()).toEqual [0, 15]
        expect(cursor2.getBufferPosition()).toEqual [1, 24]

        editor.deleteToNextWordBoundary()
        expect(buffer.lineForRow(0)).toBe 'var quicksort =() {'
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it{'
        expect(cursor1.getBufferPosition()).toEqual [0, 15]
        expect(cursor2.getBufferPosition()).toEqual [1, 24]

    describe "when text is selected", ->
      it "deletes only selected text", ->
        editor.setSelectedBufferRange([[1, 24], [1, 27]])
        editor.deleteToNextWordBoundary()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'

  describe ".deleteToBeginningOfWord()", ->
    describe "when no text is selected", ->
      it "deletes all text between the cursor and the beginning of the word", ->
        editor.setCursorBufferPosition([1, 24])
        editor.addCursorAtBufferPosition([3, 5])
        [cursor1, cursor2] = editor.getCursors()

        editor.deleteToBeginningOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(ems) {'
        expect(buffer.lineForRow(3)).toBe '    ar pivot = items.shift(), current, left = [], right = [];'
        expect(cursor1.getBufferPosition()).toEqual [1, 22]
        expect(cursor2.getBufferPosition()).toEqual [3, 4]

        editor.deleteToBeginningOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = functionems) {'
        expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return itemsar pivot = items.shift(), current, left = [], right = [];'
        expect(cursor1.getBufferPosition()).toEqual [1, 21]
        expect(cursor2.getBufferPosition()).toEqual [2, 39]

        editor.deleteToBeginningOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = ems) {'
        expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return ar pivot = items.shift(), current, left = [], right = [];'
        expect(cursor1.getBufferPosition()).toEqual [1, 13]
        expect(cursor2.getBufferPosition()).toEqual [2, 34]

        editor.setText('  var sort')
        editor.setCursorBufferPosition([0, 2])
        editor.deleteToBeginningOfWord()
        expect(buffer.lineForRow(0)).toBe 'var sort'

    describe "when text is selected", ->
      it "deletes only selected text", ->
        editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
        editor.deleteToBeginningOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
        expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'

  describe '.deleteToEndOfLine()', ->
    describe 'when no text is selected', ->
      it 'deletes all text between the cursor and the end of the line', ->
        editor.setCursorBufferPosition([1, 24])
        editor.addCursorAtBufferPosition([2, 5])
        [cursor1, cursor2] = editor.getCursors()

        editor.deleteToEndOfLine()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it'
        expect(buffer.lineForRow(2)).toBe '    i'
        expect(cursor1.getBufferPosition()).toEqual [1, 24]
        expect(cursor2.getBufferPosition()).toEqual [2, 5]

      describe 'when at the end of the line', ->
        it 'deletes the next newline', ->
          editor.setCursorBufferPosition([1, 30])
          editor.deleteToEndOfLine()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

    describe 'when text is selected', ->
      it 'deletes only the text in the selection', ->
        editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
        editor.deleteToEndOfLine()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
        expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'

  describe ".deleteToBeginningOfLine()", ->
    describe "when no text is selected", ->
      it "deletes all text between the cursor and the beginning of the line", ->
        editor.setCursorBufferPosition([1, 24])
        editor.addCursorAtBufferPosition([2, 5])
        [cursor1, cursor2] = editor.getCursors()

        editor.deleteToBeginningOfLine()
        expect(buffer.lineForRow(1)).toBe 'ems) {'
        expect(buffer.lineForRow(2)).toBe 'f (items.length <= 1) return items;'
        expect(cursor1.getBufferPosition()).toEqual [1, 0]
        expect(cursor2.getBufferPosition()).toEqual [2, 0]

      describe "when at the beginning of the line", ->
        it "deletes the newline", ->
          editor.setCursorBufferPosition([2])
          editor.deleteToBeginningOfLine()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

    describe "when text is selected", ->
      it "still deletes all text to begginning of the line", ->
        editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
        editor.deleteToBeginningOfLine()
        expect(buffer.lineForRow(1)).toBe 'ems) {'
        expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'

  describe ".delete()", ->
    describe "when there is a single cursor", ->
      describe "when the cursor is on the middle of a line", ->
        it "deletes the character following the cursor", ->
          editor.setCursorScreenPosition([1, 6])
          editor.delete()
          expect(buffer.lineForRow(1)).toBe '  var ort = function(items) {'

      describe "when the cursor is on the end of a line", ->
        it "joins the line with the following line", ->
          editor.setCursorScreenPosition([1, buffer.lineForRow(1).length])
          editor.delete()
          expect(buffer.lineForRow(1)).toBe '  var sort = function(items) {    if (items.length <= 1) return items;'

      describe "when the cursor is on the last column of the last line", ->
        it "does nothing, but doesn't raise an error", ->
          editor.setCursorScreenPosition([12, buffer.lineForRow(12).length])
          editor.delete()
          expect(buffer.lineForRow(12)).toBe '};'

      describe "when the cursor is before a fold", ->
        it "only deletes the lines inside the fold", ->
          editor.foldBufferRange([[3, 6], [4, 8]])
          editor.setCursorScreenPosition([3, 6])
          cursorPositionBefore = editor.getCursorScreenPosition()

          editor.delete()

          expect(buffer.lineForRow(3)).toBe "    vae(items.length > 0) {"
          expect(buffer.lineForRow(4)).toBe "      current = items.shift();"
          expect(editor.getCursorScreenPosition()).toEqual cursorPositionBefore

      describe "when the cursor is in the middle a line above a fold", ->
        it "deletes as normal", ->
          editor.foldBufferRow(4)
          editor.setCursorScreenPosition([3, 4])
          cursorPositionBefore = editor.getCursorScreenPosition()

          editor.delete()

          expect(buffer.lineForRow(3)).toBe "    ar pivot = items.shift(), current, left = [], right = [];"
          expect(editor.isFoldedAtScreenRow(4)).toBe(true)
          expect(editor.getCursorScreenPosition()).toEqual [3, 4]

      describe "when the cursor is inside a fold", ->
        it "removes the folded content after the cursor", ->
          editor.foldBufferRange([[2, 6], [6, 21]])
          editor.setCursorBufferPosition([4, 9])

          editor.delete()

          expect(buffer.lineForRow(2)).toBe '    if (items.length <= 1) return items;'
          expect(buffer.lineForRow(3)).toBe '    var pivot = items.shift(), current, left = [], right = [];'
          expect(buffer.lineForRow(4)).toBe '    while ? left.push(current) : right.push(current);'
          expect(buffer.lineForRow(5)).toBe '    }'
          expect(editor.getCursorBufferPosition()).toEqual [4, 9]

    describe "when there are multiple cursors", ->
      describe "when cursors are on the same line", ->
        it "removes the characters following each cursor", ->
          editor.setCursorScreenPosition([3, 13])
          editor.addCursorAtScreenPosition([3, 38])

          editor.delete()

          expect(editor.lineTextForBufferRow(3)).toBe "    var pivot= items.shift(), current left = [], right = [];"

          [cursor1, cursor2] = editor.getCursors()
          expect(cursor1.getBufferPosition()).toEqual [3, 13]
          expect(cursor2.getBufferPosition()).toEqual [3, 37]

          [selection1, selection2] = editor.getSelections()
          expect(selection1.isEmpty()).toBeTruthy()
          expect(selection2.isEmpty()).toBeTruthy()

      describe "when cursors are on different lines", ->
        describe "when the cursors are in the middle of the lines", ->
          it "removes the characters following each cursor", ->
            editor.setCursorScreenPosition([3, 13])
            editor.addCursorAtScreenPosition([4, 10])

            editor.delete()

            expect(editor.lineTextForBufferRow(3)).toBe "    var pivot= items.shift(), current, left = [], right = [];"
            expect(editor.lineTextForBufferRow(4)).toBe "    while(tems.length > 0) {"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [3, 13]
            expect(cursor2.getBufferPosition()).toEqual [4, 10]

            [selection1, selection2] = editor.getSelections()
            expect(selection1.isEmpty()).toBeTruthy()
            expect(selection2.isEmpty()).toBeTruthy()

        describe "when the cursors are at the end of their lines", ->
          it "removes the newlines following each cursor", ->
            editor.setCursorScreenPosition([0, 29])
            editor.addCursorAtScreenPosition([1, 30])

            editor.delete()

            expect(editor.lineTextForBufferRow(0)).toBe "var quicksort = function () {  var sort = function(items) {    if (items.length <= 1) return items;"

            [cursor1, cursor2] = editor.getCursors()
            expect(cursor1.getBufferPosition()).toEqual [0, 29]
            expect(cursor2.getBufferPosition()).toEqual [0, 59]

    describe "when there is a single selection", ->
      it "deletes the selection, but not the character following it", ->
        editor.setSelectedBufferRanges([[[1, 24], [1, 27]], [[2, 0], [2, 4]]])
        editor.delete()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
        expect(buffer.lineForRow(2)).toBe 'if (items.length <= 1) return items;'
        expect(editor.getLastSelection().isEmpty()).toBeTruthy()

    describe "when there are multiple selections", ->
      describe "when selections are on the same line", ->
        it "removes all selected text", ->
          editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 16], [0, 24]]])
          editor.delete()
          expect(editor.lineTextForBufferRow(0)).toBe 'var  =  () {'

  describe ".deleteToEndOfWord()", ->
    describe "when no text is selected", ->
      it "deletes to the end of the word", ->
        editor.setCursorBufferPosition([1, 24])
        editor.addCursorAtBufferPosition([2, 5])
        [cursor1, cursor2] = editor.getCursors()

        editor.deleteToEndOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'
        expect(buffer.lineForRow(2)).toBe '    i (items.length <= 1) return items;'
        expect(cursor1.getBufferPosition()).toEqual [1, 24]
        expect(cursor2.getBufferPosition()).toEqual [2, 5]

        editor.deleteToEndOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it {'
        expect(buffer.lineForRow(2)).toBe '    iitems.length <= 1) return items;'
        expect(cursor1.getBufferPosition()).toEqual [1, 24]
        expect(cursor2.getBufferPosition()).toEqual [2, 5]

    describe "when text is selected", ->
      it "deletes only selected text", ->
        editor.setSelectedBufferRange([[1, 24], [1, 27]])
        editor.deleteToEndOfWord()
        expect(buffer.lineForRow(1)).toBe '  var sort = function(it) {'

  describe ".indent()", ->
    describe "when the selection is empty", ->
      describe "when autoIndent is disabled", ->
        describe "if 'softTabs' is true (the default)", ->
          it "inserts 'tabLength' spaces into the buffer", ->
            tabRegex = new RegExp("^[ ]{#{editor.getTabLength()}}")
            expect(buffer.lineForRow(0)).not.toMatch(tabRegex)
            editor.indent()
            expect(buffer.lineForRow(0)).toMatch(tabRegex)

          it "respects the tab stops when cursor is in the middle of a tab", ->
            editor.setTabLength(4)
            buffer.insert([12, 2], "\n ")
            editor.setCursorBufferPosition [13, 1]
            editor.indent()
            expect(buffer.lineForRow(13)).toMatch /^\s+$/
            expect(buffer.lineForRow(13).length).toBe 4
            expect(editor.getCursorBufferPosition()).toEqual [13, 4]

            buffer.insert([13, 0], "  ")
            editor.setCursorBufferPosition [13, 6]
            editor.indent()
            expect(buffer.lineForRow(13).length).toBe 8

        describe "if 'softTabs' is false", ->
          it "insert a \t into the buffer", ->
            editor.setSoftTabs(false)
            expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
            editor.indent()
            expect(buffer.lineForRow(0)).toMatch(/^\t/)

      describe "when autoIndent is enabled", ->
        describe "when the cursor's column is less than the suggested level of indentation", ->
          describe "when 'softTabs' is true (the default)", ->
            it "moves the cursor to the end of the leading whitespace and inserts enough whitespace to bring the line to the suggested level of indentaion", ->
              buffer.insert([5, 0], "  \n")
              editor.setCursorBufferPosition [5, 0]
              editor.indent(autoIndent: true)
              expect(buffer.lineForRow(5)).toMatch /^\s+$/
              expect(buffer.lineForRow(5).length).toBe 6
              expect(editor.getCursorBufferPosition()).toEqual [5, 6]

            it "respects the tab stops when cursor is in the middle of a tab", ->
              editor.setTabLength(4)
              buffer.insert([12, 2], "\n ")
              editor.setCursorBufferPosition [13, 1]
              editor.indent(autoIndent: true)
              expect(buffer.lineForRow(13)).toMatch /^\s+$/
              expect(buffer.lineForRow(13).length).toBe 4
              expect(editor.getCursorBufferPosition()).toEqual [13, 4]

              buffer.insert([13, 0], "  ")
              editor.setCursorBufferPosition [13, 6]
              editor.indent(autoIndent: true)
              expect(buffer.lineForRow(13).length).toBe 8

          describe "when 'softTabs' is false", ->
            it "moves the cursor to the end of the leading whitespace and inserts enough tabs to bring the line to the suggested level of indentaion", ->
              convertToHardTabs(buffer)
              editor.setSoftTabs(false)
              buffer.insert([5, 0], "\t\n")
              editor.setCursorBufferPosition [5, 0]
              editor.indent(autoIndent: true)
              expect(buffer.lineForRow(5)).toMatch /^\t\t\t$/
              expect(editor.getCursorBufferPosition()).toEqual [5, 3]

            describe "when the difference between the suggested level of indentation and the current level of indentation is greater than 0 but less than 1", ->
              it "inserts one tab", ->
                editor.setSoftTabs(false)
                buffer.setText(" \ntest")
                editor.setCursorBufferPosition [1, 0]

                editor.indent(autoIndent: true)
                expect(buffer.lineForRow(1)).toBe '\ttest'
                expect(editor.getCursorBufferPosition()).toEqual [1, 1]

        describe "when the line's indent level is greater than the suggested level of indentation", ->
          describe "when 'softTabs' is true (the default)", ->
            it "moves the cursor to the end of the leading whitespace and inserts 'tabLength' spaces into the buffer", ->
              buffer.insert([7, 0], "      \n")
              editor.setCursorBufferPosition [7, 2]
              editor.indent(autoIndent: true)
              expect(buffer.lineForRow(7)).toMatch /^\s+$/
              expect(buffer.lineForRow(7).length).toBe 8
              expect(editor.getCursorBufferPosition()).toEqual [7, 8]

          describe "when 'softTabs' is false", ->
            it "moves the cursor to the end of the leading whitespace and inserts \t into the buffer", ->
              convertToHardTabs(buffer)
              editor.setSoftTabs(false)
              buffer.insert([7, 0], "\t\t\t\n")
              editor.setCursorBufferPosition [7, 1]
              editor.indent(autoIndent: true)
              expect(buffer.lineForRow(7)).toMatch /^\t\t\t\t$/
              expect(editor.getCursorBufferPosition()).toEqual [7, 4]

    describe "when the selection is not empty", ->
      it "indents the selected lines", ->
        editor.setSelectedBufferRange([[0, 0], [10, 0]])
        selection = editor.getLastSelection()
        spyOn(selection, "indentSelectedRows")
        editor.indent()
        expect(selection.indentSelectedRows).toHaveBeenCalled()

    describe "if editor.softTabs is false", ->
      it "inserts a tab character into the buffer", ->
        editor.setSoftTabs(false)
        expect(buffer.lineForRow(0)).not.toMatch(/^\t/)
        editor.indent()
        expect(buffer.lineForRow(0)).toMatch(/^\t/)
        expect(editor.getCursorBufferPosition()).toEqual [0, 1]
        expect(editor.getCursorScreenPosition()).toEqual [0, editor.getTabLength()]

        editor.indent()
        expect(buffer.lineForRow(0)).toMatch(/^\t\t/)
        expect(editor.getCursorBufferPosition()).toEqual [0, 2]
        expect(editor.getCursorScreenPosition()).toEqual [0, editor.getTabLength() * 2]

  describe ".indentSelectedRows()", ->
    describe "when nothing is selected", ->
      describe "when softTabs is enabled", ->
        it "indents line and retains selection", ->
          editor.setSelectedBufferRange([[0, 3], [0, 3]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "  var quicksort = function () {"
          expect(editor.getSelectedBufferRange()).toEqual [[0, 3 + editor.getTabLength()], [0, 3 + editor.getTabLength()]]

      describe "when softTabs is disabled", ->
        it "indents line and retains selection", ->
          convertToHardTabs(buffer)
          editor.setSoftTabs(false)
          editor.setSelectedBufferRange([[0, 3], [0, 3]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
          expect(editor.getSelectedBufferRange()).toEqual [[0, 3 + 1], [0, 3 + 1]]

    describe "when one line is selected", ->
      describe "when softTabs is enabled", ->
        it "indents line and retains selection", ->
          editor.setSelectedBufferRange([[0, 4], [0, 14]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "#{editor.getTabText()}var quicksort = function () {"
          expect(editor.getSelectedBufferRange()).toEqual [[0, 4 + editor.getTabLength()], [0, 14 + editor.getTabLength()]]

      describe "when softTabs is disabled", ->
        it "indents line and retains selection", ->
          convertToHardTabs(buffer)
          editor.setSoftTabs(false)
          editor.setSelectedBufferRange([[0, 4], [0, 14]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
          expect(editor.getSelectedBufferRange()).toEqual [[0, 4 + 1], [0, 14 + 1]]

    describe "when multiple lines are selected", ->
      describe "when softTabs is enabled", ->
        it "indents selected lines (that are not empty) and retains selection", ->
          editor.setSelectedBufferRange([[9, 1], [11, 15]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(9)).toBe "    };"
          expect(buffer.lineForRow(10)).toBe ""
          expect(buffer.lineForRow(11)).toBe "    return sort(Array.apply(this, arguments));"
          expect(editor.getSelectedBufferRange()).toEqual [[9, 1 + editor.getTabLength()], [11, 15 + editor.getTabLength()]]

        it "does not indent the last row if the selection ends at column 0", ->
          editor.setSelectedBufferRange([[9, 1], [11, 0]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(9)).toBe "    };"
          expect(buffer.lineForRow(10)).toBe ""
          expect(buffer.lineForRow(11)).toBe "  return sort(Array.apply(this, arguments));"
          expect(editor.getSelectedBufferRange()).toEqual [[9, 1 + editor.getTabLength()], [11, 0]]

      describe "when softTabs is disabled", ->
        it "indents selected lines (that are not empty) and retains selection", ->
          convertToHardTabs(buffer)
          editor.setSoftTabs(false)
          editor.setSelectedBufferRange([[9, 1], [11, 15]])
          editor.indentSelectedRows()
          expect(buffer.lineForRow(9)).toBe "\t\t};"
          expect(buffer.lineForRow(10)).toBe ""
          expect(buffer.lineForRow(11)).toBe "\t\treturn sort(Array.apply(this, arguments));"
          expect(editor.getSelectedBufferRange()).toEqual [[9, 1 + 1], [11, 15 + 1]]

  describe ".outdentSelectedRows()", ->
    describe "when nothing is selected", ->
      it "outdents line and retains selection", ->
        editor.setSelectedBufferRange([[1, 3], [1, 3]])
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(editor.getSelectedBufferRange()).toEqual [[1, 3 - editor.getTabLength()], [1, 3 - editor.getTabLength()]]

      it "outdents when indent is less than a tab length", ->
        editor.insertText(' ')
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

      it "outdents a single hard tab when indent is multiple hard tabs and and the session is using soft tabs", ->
        editor.insertText('\t\t')
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "\tvar quicksort = function () {"
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

      it "outdents when a mix of hard tabs and soft tabs are used", ->
        editor.insertText('\t   ')
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "   var quicksort = function () {"
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe " var quicksort = function () {"
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

      it "outdents only up to the first non-space non-tab character", ->
        editor.insertText(' \tfoo\t ')
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "\tfoo\t var quicksort = function () {"
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "foo\t var quicksort = function () {"
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "foo\t var quicksort = function () {"

    describe "when one line is selected", ->
      it "outdents line and retains editor", ->
        editor.setSelectedBufferRange([[1, 4], [1, 14]])
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(editor.getSelectedBufferRange()).toEqual [[1, 4 - editor.getTabLength()], [1, 14 - editor.getTabLength()]]

    describe "when multiple lines are selected", ->
      it "outdents selected lines and retains editor", ->
        editor.setSelectedBufferRange([[0, 1], [3, 15]])
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
        expect(buffer.lineForRow(3)).toBe "  var pivot = items.shift(), current, left = [], right = [];"
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [3, 15 - editor.getTabLength()]]

      it "does not outdent the last line of the selection if it ends at column 0", ->
        editor.setSelectedBufferRange([[0, 1], [3, 0]])
        editor.outdentSelectedRows()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "var sort = function(items) {"
        expect(buffer.lineForRow(2)).toBe "  if (items.length <= 1) return items;"
        expect(buffer.lineForRow(3)).toBe "    var pivot = items.shift(), current, left = [], right = [];"

        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [3, 0]]

  describe ".autoIndentSelectedRows", ->
    it "auto-indents the selection", ->
      editor.setCursorBufferPosition([2, 0])
      editor.insertText("function() {\ninside=true\n}\n  i=1\n")
      editor.getLastSelection().setBufferRange([[2, 0], [6, 0]])
      editor.autoIndentSelectedRows()

      expect(editor.lineTextForBufferRow(2)).toBe "    function() {"
      expect(editor.lineTextForBufferRow(3)).toBe "      inside=true"
      expect(editor.lineTextForBufferRow(4)).toBe "    }"
      expect(editor.lineTextForBufferRow(5)).toBe "    i=1"

  describe ".toggleLineCommentsInSelection()", ->
    it "toggles comments on the selected lines", ->
      editor.setSelectedBufferRange([[4, 5], [7, 5]])
      editor.toggleLineCommentsInSelection()

      expect(buffer.lineForRow(4)).toBe "    // while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "    //   current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "    //   current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "    // }"
      expect(editor.getSelectedBufferRange()).toEqual [[4, 8], [7, 8]]

      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "      current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "      current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "    }"

    it "does not comment the last line of a non-empty selection if it ends at column 0", ->
      editor.setSelectedBufferRange([[4, 5], [7, 0]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(4)).toBe "    // while(items.length > 0) {"
      expect(buffer.lineForRow(5)).toBe "    //   current = items.shift();"
      expect(buffer.lineForRow(6)).toBe "    //   current < pivot ? left.push(current) : right.push(current);"
      expect(buffer.lineForRow(7)).toBe "    }"

    it "uncomments lines if all lines match the comment regex", ->
      editor.setSelectedBufferRange([[0, 0], [0, 1]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(0)).toBe "// var quicksort = function () {"

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(0)).toBe "// // var quicksort = function () {"
      expect(buffer.lineForRow(1)).toBe "//   var sort = function(items) {"
      expect(buffer.lineForRow(2)).toBe "//     if (items.length <= 1) return items;"

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(0)).toBe "// var quicksort = function () {"
      expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
      expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"

      editor.setSelectedBufferRange([[0, 0], [0, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"

    it "uncomments commented lines separated by an empty line", ->
      editor.setSelectedBufferRange([[0, 0], [1, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(0)).toBe "// var quicksort = function () {"
      expect(buffer.lineForRow(1)).toBe "//   var sort = function(items) {"

      buffer.insert([0, Infinity], '\n')

      editor.setSelectedBufferRange([[0, 0], [2, Infinity]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
      expect(buffer.lineForRow(1)).toBe ""
      expect(buffer.lineForRow(2)).toBe "  var sort = function(items) {"

    it "preserves selection emptiness", ->
      editor.setCursorBufferPosition([4, 0])
      editor.toggleLineCommentsInSelection()
      expect(editor.getLastSelection().isEmpty()).toBeTruthy()

    it "does not explode if the current language mode has no comment regex", ->
      editor.destroy()

      waitsForPromise ->
        atom.workspace.open(null, autoIndent: false).then (o) -> editor = o

      runs ->
        editor.setSelectedBufferRange([[4, 5], [4, 5]])
        editor.toggleLineCommentsInSelection()
        expect(buffer.lineForRow(4)).toBe "    while(items.length > 0) {"

    it "does nothing for empty lines and null grammar", ->
      runs ->
        editor.setGrammar(atom.grammars.grammarForScopeName('text.plain.null-grammar'))
        editor.setCursorBufferPosition([10, 0])
        editor.toggleLineCommentsInSelection()
        expect(editor.buffer.lineForRow(10)).toBe ""

    it "uncomments when the line lacks the trailing whitespace in the comment regex", ->
      editor.setCursorBufferPosition([10, 0])
      editor.toggleLineCommentsInSelection()

      expect(buffer.lineForRow(10)).toBe "// "
      expect(editor.getSelectedBufferRange()).toEqual [[10, 3], [10, 3]]
      editor.backspace()
      expect(buffer.lineForRow(10)).toBe "//"

      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(10)).toBe ""
      expect(editor.getSelectedBufferRange()).toEqual [[10, 0], [10, 0]]

    it "uncomments when the line has leading whitespace", ->
      editor.setCursorBufferPosition([10, 0])
      editor.toggleLineCommentsInSelection()

      expect(buffer.lineForRow(10)).toBe "// "
      editor.moveToBeginningOfLine()
      editor.insertText("  ")
      editor.setSelectedBufferRange([[10, 0], [10, 0]])
      editor.toggleLineCommentsInSelection()
      expect(buffer.lineForRow(10)).toBe "  "

  describe ".undo() and .redo()", ->
    it "undoes/redoes the last change", ->
      editor.insertText("foo")
      editor.undo()
      expect(buffer.lineForRow(0)).not.toContain "foo"

      editor.redo()
      expect(buffer.lineForRow(0)).toContain "foo"

    it "batches the undo / redo of changes caused by multiple cursors", ->
      editor.setCursorScreenPosition([0, 0])
      editor.addCursorAtScreenPosition([1, 0])

      editor.insertText("foo")
      editor.backspace()

      expect(buffer.lineForRow(0)).toContain "fovar"
      expect(buffer.lineForRow(1)).toContain "fo "

      editor.undo()

      expect(buffer.lineForRow(0)).toContain "foo"
      expect(buffer.lineForRow(1)).toContain "foo"

      editor.redo()

      expect(buffer.lineForRow(0)).not.toContain "foo"
      expect(buffer.lineForRow(0)).toContain "fovar"

    it "restores cursors and selections to their states before and after undone and redone changes", ->
      editor.setSelectedBufferRanges([
        [[0, 0], [0, 0]],
        [[1, 0], [1, 3]],
      ])
      editor.insertText("abc")

      expect(editor.getSelectedBufferRanges()).toEqual [
        [[0, 3], [0, 3]],
        [[1, 3], [1, 3]]
      ]

      editor.setCursorBufferPosition([0, 0])
      editor.setSelectedBufferRanges([
        [[2, 0], [2, 0]],
        [[3, 0], [3, 0]],
        [[4, 0], [4, 3]],
      ])
      editor.insertText("def")

      expect(editor.getSelectedBufferRanges()).toEqual [
        [[2, 3], [2, 3]],
        [[3, 3], [3, 3]]
        [[4, 3], [4, 3]]
      ]

      editor.setCursorBufferPosition([0, 0])
      editor.undo()

      expect(editor.getSelectedBufferRanges()).toEqual [
        [[2, 0], [2, 0]],
        [[3, 0], [3, 0]],
        [[4, 0], [4, 3]],
      ]

      editor.undo()

      expect(editor.getSelectedBufferRanges()).toEqual [
        [[0, 0], [0, 0]],
        [[1, 0], [1, 3]]
      ]

      editor.redo()

      expect(editor.getSelectedBufferRanges()).toEqual [
        [[0, 3], [0, 3]],
        [[1, 3], [1, 3]]
      ]

      editor.redo()

      expect(editor.getSelectedBufferRanges()).toEqual [
        [[2, 3], [2, 3]],
        [[3, 3], [3, 3]]
        [[4, 3], [4, 3]]
      ]

    it "restores the selected ranges after undo and redo", ->
      editor.setSelectedBufferRanges([[[1, 6], [1, 10]], [[1, 22], [1, 27]]])
      editor.delete()
      editor.delete()

      selections = editor.getSelections()
      expect(buffer.lineForRow(1)).toBe '  var = function( {'

      expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 17], [1, 17]]]

      editor.undo()
      expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 18], [1, 18]]]

      editor.undo()
      expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 10]], [[1, 22], [1, 27]]]

      editor.redo()
      expect(editor.getSelectedBufferRanges()).toEqual [[[1, 6], [1, 6]], [[1, 18], [1, 18]]]

    xit "restores folds after undo and redo", ->
      editor.foldBufferRow(1)
      editor.setSelectedBufferRange([[1, 0], [10, Infinity]], preserveFolds: true)
      expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()

      editor.insertText """
        \  // testing
          function foo() {
            return 1 + 2;
          }
      """
      expect(editor.isFoldedAtBufferRow(1)).toBeFalsy()
      editor.foldBufferRow(2)

      editor.undo()
      expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()
      expect(editor.isFoldedAtBufferRow(9)).toBeTruthy()
      expect(editor.isFoldedAtBufferRow(10)).toBeFalsy()

      editor.redo()
      expect(editor.isFoldedAtBufferRow(1)).toBeFalsy()
      expect(editor.isFoldedAtBufferRow(2)).toBeTruthy()

  describe "::transact", ->
    it "restores the selection when the transaction is undone/redone", ->
      buffer.setText('1234')
      editor.setSelectedBufferRange([[0, 1], [0, 3]])

      editor.transact ->
        editor.delete()
        editor.moveToEndOfLine()
        editor.insertText('5')
        expect(buffer.getText()).toBe '145'

      editor.undo()
      expect(buffer.getText()).toBe '1234'
      expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 3]]

      editor.redo()
      expect(buffer.getText()).toBe '145'
      expect(editor.getSelectedBufferRange()).toEqual [[0, 3], [0, 3]]

  describe "when the buffer is changed (via its direct api, rather than via than edit session)", ->
    it "moves the cursor so it is in the same relative position of the buffer", ->
      expect(editor.getCursorScreenPosition()).toEqual [0, 0]
      editor.addCursorAtScreenPosition([0, 5])
      editor.addCursorAtScreenPosition([1, 0])
      [cursor1, cursor2, cursor3] = editor.getCursors()

      buffer.insert([0, 1], 'abc')

      expect(cursor1.getScreenPosition()).toEqual [0, 0]
      expect(cursor2.getScreenPosition()).toEqual [0, 8]
      expect(cursor3.getScreenPosition()).toEqual [1, 0]

    it "does not destroy cursors or selections when a change encompasses them", ->
      cursor = editor.getLastCursor()
      cursor.setBufferPosition [3, 3]
      editor.buffer.delete([[3, 1], [3, 5]])
      expect(cursor.getBufferPosition()).toEqual [3, 1]
      expect(editor.getCursors().indexOf(cursor)).not.toBe -1

      selection = editor.getLastSelection()
      selection.setBufferRange [[3, 5], [3, 10]]
      editor.buffer.delete [[3, 3], [3, 8]]
      expect(selection.getBufferRange()).toEqual [[3, 3], [3, 5]]
      expect(editor.getSelections().indexOf(selection)).not.toBe -1

    it "merges cursors when the change causes them to overlap", ->
      editor.setCursorScreenPosition([0, 0])
      editor.addCursorAtScreenPosition([0, 2])
      editor.addCursorAtScreenPosition([1, 2])

      [cursor1, cursor2, cursor3] = editor.getCursors()
      expect(editor.getCursors().length).toBe 3

      buffer.delete([[0, 0], [0, 2]])

      expect(editor.getCursors().length).toBe 2
      expect(editor.getCursors()).toEqual [cursor1, cursor3]
      expect(cursor1.getBufferPosition()).toEqual [0, 0]
      expect(cursor3.getBufferPosition()).toEqual [1, 2]

  describe ".moveSelectionLeft()", ->
    it "moves one active selection on one line one column to the left", ->
      editor.setSelectedBufferRange [[0, 4], [0, 13]]
      expect(editor.getSelectedText()).toBe 'quicksort'

      editor.moveSelectionLeft()

      expect(editor.getSelectedText()).toBe 'quicksort'
      expect(editor.getSelectedBufferRange()).toEqual [[0, 3], [0, 12]]

    it "moves multiple active selections on one line one column to the left", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 16], [0, 24]]])
      selections = editor.getSelections()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'function'

      editor.moveSelectionLeft()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'function'
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 3], [0, 12]], [[0, 15], [0, 23]]]

    it "moves multiple active selections on multiple lines one column to the left", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
      selections = editor.getSelections()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'sort'

      editor.moveSelectionLeft()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'sort'
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 3], [0, 12]], [[1, 5], [1, 9]]]

    describe "when a selection is at the first column of a line", ->
      it "does not change the selection", ->
        editor.setSelectedBufferRanges([[[0, 0], [0, 3]], [[1, 0], [1, 3]]])
        selections = editor.getSelections()

        expect(selections[0].getText()).toBe 'var'
        expect(selections[1].getText()).toBe '  v'

        editor.moveSelectionLeft()
        editor.moveSelectionLeft()

        expect(selections[0].getText()).toBe 'var'
        expect(selections[1].getText()).toBe '  v'
        expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [0, 3]], [[1, 0], [1, 3]]]

      describe "when multiple selections are active on one line", ->
        it "does not change the selection", ->
          editor.setSelectedBufferRanges([[[0, 0], [0, 3]], [[0, 4], [0, 13]]])
          selections = editor.getSelections()

          expect(selections[0].getText()).toBe 'var'
          expect(selections[1].getText()).toBe 'quicksort'

          editor.moveSelectionLeft()

          expect(selections[0].getText()).toBe 'var'
          expect(selections[1].getText()).toBe 'quicksort'
          expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [0, 3]], [[0, 4], [0, 13]]]

  describe ".moveSelectionRight()", ->
    it "moves one active selection on one line one column to the right", ->
      editor.setSelectedBufferRange [[0, 4], [0, 13]]
      expect(editor.getSelectedText()).toBe 'quicksort'

      editor.moveSelectionRight()

      expect(editor.getSelectedText()).toBe 'quicksort'
      expect(editor.getSelectedBufferRange()).toEqual [[0, 5], [0, 14]]

    it "moves multiple active selections on one line one column to the right", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[0, 16], [0, 24]]])
      selections = editor.getSelections()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'function'

      editor.moveSelectionRight()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'function'
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 5], [0, 14]], [[0, 17], [0, 25]]]

    it "moves multiple active selections on multiple lines one column to the right", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
      selections = editor.getSelections()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'sort'

      editor.moveSelectionRight()

      expect(selections[0].getText()).toBe 'quicksort'
      expect(selections[1].getText()).toBe 'sort'
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 5], [0, 14]], [[1, 7], [1, 11]]]

    describe "when a selection is at the last column of a line", ->
      it "does not change the selection", ->
        editor.setSelectedBufferRanges([[[2, 34], [2, 40]], [[5, 22], [5, 30]]])
        selections = editor.getSelections()

        expect(selections[0].getText()).toBe 'items;'
        expect(selections[1].getText()).toBe 'shift();'

        editor.moveSelectionRight()
        editor.moveSelectionRight()

        expect(selections[0].getText()).toBe 'items;'
        expect(selections[1].getText()).toBe 'shift();'
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 34], [2, 40]], [[5, 22], [5, 30]]]

      describe "when multiple selections are active on one line", ->
        it "does not change the selection", ->
          editor.setSelectedBufferRanges([[[2, 27], [2, 33]], [[2, 34], [2, 40]]])
          selections = editor.getSelections()

          expect(selections[0].getText()).toBe 'return'
          expect(selections[1].getText()).toBe 'items;'

          editor.moveSelectionRight()

          expect(selections[0].getText()).toBe 'return'
          expect(selections[1].getText()).toBe 'items;'
          expect(editor.getSelectedBufferRanges()).toEqual [[[2, 27], [2, 33]], [[2, 34], [2, 40]]]
