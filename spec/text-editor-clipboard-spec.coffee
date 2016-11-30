clipboard = require '../src/safe-clipboard'

describe "TextEditor clipboard", ->
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

  describe ".cutSelectedText()", ->
    it "removes the selected text from the buffer and places it on the clipboard", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
      editor.cutSelectedText()
      expect(buffer.lineForRow(0)).toBe "var  = function () {"
      expect(buffer.lineForRow(1)).toBe "  var  = function(items) {"
      expect(clipboard.readText()).toBe 'quicksort\nsort'

    describe "when no text is selected", ->
      beforeEach ->
        editor.setSelectedBufferRanges([
          [[0, 0], [0, 0]],
          [[5, 0], [5, 0]],
        ])

      it "cuts the lines on which there are cursors", ->
        editor.cutSelectedText()
        expect(buffer.getLineCount()).toBe(11)
        expect(buffer.lineForRow(1)).toBe("    if (items.length <= 1) return items;")
        expect(buffer.lineForRow(4)).toBe("      current < pivot ? left.push(current) : right.push(current);")
        expect(atom.clipboard.read()).toEqual """
          var quicksort = function () {

                current = items.shift();

        """

    describe "when many selections get added in shuffle order", ->
      it "cuts them in order", ->
        editor.setSelectedBufferRanges([
          [[2, 8], [2, 13]]
          [[0, 4], [0, 13]],
          [[1, 6], [1, 10]],
        ])
        editor.cutSelectedText()
        expect(atom.clipboard.read()).toEqual """
          quicksort
          sort
          items
        """

  describe ".cutToEndOfLine()", ->
    describe "when soft wrap is on", ->
      it "cuts up to the end of the line", ->
        editor.setSoftWrapped(true)
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(25)
        editor.setCursorScreenPosition([2, 6])
        editor.cutToEndOfLine()
        expect(editor.lineTextForScreenRow(2)).toBe '  var  function(items) {'

    describe "when soft wrap is off", ->
      describe "when nothing is selected", ->
        it "cuts up to the end of the line", ->
          editor.setCursorBufferPosition([2, 20])
          editor.addCursorAtBufferPosition([3, 20])
          editor.cutToEndOfLine()
          expect(buffer.lineForRow(2)).toBe '    if (items.length'
          expect(buffer.lineForRow(3)).toBe '    var pivot = item'
          expect(atom.clipboard.read()).toBe ' <= 1) return items;\ns.shift(), current, left = [], right = [];'

      describe "when text is selected", ->
        it "only cuts the selected text, not to the end of the line", ->
          editor.setSelectedBufferRanges([[[2, 20], [2, 30]], [[3, 20], [3, 20]]])

          editor.cutToEndOfLine()

          expect(buffer.lineForRow(2)).toBe '    if (items.lengthurn items;'
          expect(buffer.lineForRow(3)).toBe '    var pivot = item'
          expect(atom.clipboard.read()).toBe ' <= 1) ret\ns.shift(), current, left = [], right = [];'

  describe ".cutToEndOfBufferLine()", ->
    beforeEach ->
      editor.setSoftWrapped(true)
      editor.setEditorWidthInChars(10)

    describe "when nothing is selected", ->
      it "cuts up to the end of the buffer line", ->
        editor.setCursorBufferPosition([2, 20])
        editor.addCursorAtBufferPosition([3, 20])

        editor.cutToEndOfBufferLine()

        expect(buffer.lineForRow(2)).toBe '    if (items.length'
        expect(buffer.lineForRow(3)).toBe '    var pivot = item'
        expect(atom.clipboard.read()).toBe ' <= 1) return items;\ns.shift(), current, left = [], right = [];'

    describe "when text is selected", ->
      it "only cuts the selected text, not to the end of the buffer line", ->
        editor.setSelectedBufferRanges([[[2, 20], [2, 30]], [[3, 20], [3, 20]]])

        editor.cutToEndOfBufferLine()

        expect(buffer.lineForRow(2)).toBe '    if (items.lengthurn items;'
        expect(buffer.lineForRow(3)).toBe '    var pivot = item'
        expect(atom.clipboard.read()).toBe ' <= 1) ret\ns.shift(), current, left = [], right = [];'

  describe ".copySelectedText()", ->
    it "copies selected text onto the clipboard", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]], [[2, 8], [2, 13]]])

      editor.copySelectedText()
      expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
      expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
      expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
      expect(clipboard.readText()).toBe 'quicksort\nsort\nitems'
      expect(atom.clipboard.read()).toEqual """
        quicksort
        sort
        items
      """

    describe "when no text is selected", ->
      beforeEach ->
        editor.setSelectedBufferRanges([
          [[1, 5], [1, 5]],
          [[5, 8], [5, 8]]
        ])

      it "copies the lines on which there are cursors", ->
        editor.copySelectedText()
        expect(atom.clipboard.read()).toEqual([
          "  var sort = function(items) {\n"
          "      current = items.shift();\n"
        ].join("\n"))
        expect(editor.getSelectedBufferRanges()).toEqual([
          [[1, 5], [1, 5]],
          [[5, 8], [5, 8]]
        ])

    describe "when many selections get added in shuffle order", ->
      it "copies them in order", ->
        editor.setSelectedBufferRanges([
          [[2, 8], [2, 13]]
          [[0, 4], [0, 13]],
          [[1, 6], [1, 10]],
        ])
        editor.copySelectedText()
        expect(atom.clipboard.read()).toEqual """
          quicksort
          sort
          items
        """

  describe ".copyOnlySelectedText()", ->
    describe "when thee are multiple selections", ->
      it "copies selected text onto the clipboard", ->
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]], [[2, 8], [2, 13]]])

        editor.copyOnlySelectedText()
        expect(buffer.lineForRow(0)).toBe "var quicksort = function () {"
        expect(buffer.lineForRow(1)).toBe "  var sort = function(items) {"
        expect(buffer.lineForRow(2)).toBe "    if (items.length <= 1) return items;"
        expect(clipboard.readText()).toBe 'quicksort\nsort\nitems'
        expect(atom.clipboard.read()).toEqual """
          quicksort
          sort
          items
        """

    describe "when no text is selected", ->
      it "does not copy anything", ->
        editor.setCursorBufferPosition([1, 5])
        editor.copyOnlySelectedText()
        expect(atom.clipboard.read()).toEqual "initial clipboard content"

  describe ".pasteText()", ->
    copyText = (text, {startColumn, textEditor}={}) ->
      startColumn ?= 0
      textEditor ?= editor
      textEditor.setCursorBufferPosition([0, 0])
      textEditor.insertText(text)
      numberOfNewlines = text.match(/\n/g)?.length
      endColumn = text.match(/[^\n]*$/)[0]?.length
      textEditor.getLastSelection().setBufferRange([[0, startColumn], [numberOfNewlines, endColumn]])
      textEditor.cutSelectedText()

    it "pastes text into the buffer", ->
      editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
      atom.clipboard.write('first')
      editor.pasteText()
      expect(editor.lineTextForBufferRow(0)).toBe "var first = function () {"
      expect(editor.lineTextForBufferRow(1)).toBe "  var first = function(items) {"

    it "notifies ::onWillInsertText observers", ->
      insertedStrings = []
      editor.onWillInsertText ({text, cancel}) ->
        insertedStrings.push(text)
        cancel()

      atom.clipboard.write("hello")
      editor.pasteText()

      expect(insertedStrings).toEqual ["hello"]

    it "notifies ::onDidInsertText observers", ->
      insertedStrings = []
      editor.onDidInsertText ({text, range}) ->
        insertedStrings.push(text)

      atom.clipboard.write("hello")
      editor.pasteText()

      expect(insertedStrings).toEqual ["hello"]

    describe "when `autoIndentOnPaste` is true", ->
      beforeEach ->
        editor.update({autoIndentOnPaste: true})

      describe "when pasting multiple lines before any non-whitespace characters", ->
        it "auto-indents the lines spanned by the pasted text, based on the first pasted line", ->
          atom.clipboard.write("a(x);\n  b(x);\n    c(x);\n", indentBasis: 0)
          editor.setCursorBufferPosition([5, 0])
          editor.pasteText()

          # Adjust the indentation of the pasted lines while preserving
          # their indentation relative to each other. Also preserve the
          # indentation of the following line.
          expect(editor.lineTextForBufferRow(5)).toBe "      a(x);"
          expect(editor.lineTextForBufferRow(6)).toBe "        b(x);"
          expect(editor.lineTextForBufferRow(7)).toBe "          c(x);"
          expect(editor.lineTextForBufferRow(8)).toBe "      current = items.shift();"

        it "auto-indents lines with a mix of hard tabs and spaces without removing spaces", ->
          editor.setSoftTabs(false)
          expect(editor.indentationForBufferRow(5)).toBe(3)

          atom.clipboard.write("/**\n\t * testing\n\t * indent\n\t **/\n", indentBasis: 1)
          editor.setCursorBufferPosition([5, 0])
          editor.pasteText()

          # Do not lose the alignment spaces
          expect(editor.lineTextForBufferRow(5)).toBe("\t\t\t/**")
          expect(editor.lineTextForBufferRow(6)).toBe("\t\t\t * testing")
          expect(editor.lineTextForBufferRow(7)).toBe("\t\t\t * indent")
          expect(editor.lineTextForBufferRow(8)).toBe("\t\t\t **/")

      describe "when pasting line(s) above a line that matches the decreaseIndentPattern", ->
        it "auto-indents based on the pasted line(s) only", ->
          atom.clipboard.write("a(x);\n  b(x);\n    c(x);\n", indentBasis: 0)
          editor.setCursorBufferPosition([7, 0])
          editor.pasteText()

          expect(editor.lineTextForBufferRow(7)).toBe "      a(x);"
          expect(editor.lineTextForBufferRow(8)).toBe "        b(x);"
          expect(editor.lineTextForBufferRow(9)).toBe "          c(x);"
          expect(editor.lineTextForBufferRow(10)).toBe "    }"

      describe "when pasting a line of text without line ending", ->
        it "does not auto-indent the text", ->
          atom.clipboard.write("a(x);", indentBasis: 0)
          editor.setCursorBufferPosition([5, 0])
          editor.pasteText()

          expect(editor.lineTextForBufferRow(5)).toBe "a(x);      current = items.shift();"
          expect(editor.lineTextForBufferRow(6)).toBe "      current < pivot ? left.push(current) : right.push(current);"

      describe "when pasting on a line after non-whitespace characters", ->
        it "does not auto-indent the affected line", ->
          # Before the paste, the indentation is non-standard.
          editor.setText """
            if (x) {
                y();
            }
          """

          atom.clipboard.write(" z();\n h();")
          editor.setCursorBufferPosition([1, Infinity])

          # The indentation of the non-standard line is unchanged.
          editor.pasteText()
          expect(editor.lineTextForBufferRow(1)).toBe("    y(); z();")
          expect(editor.lineTextForBufferRow(2)).toBe(" h();")

    describe "when `autoIndentOnPaste` is false", ->
      beforeEach ->
        editor.update({autoIndentOnPaste: false})

      describe "when the cursor is indented further than the original copied text", ->
        it "increases the indentation of the copied lines to match", ->
          editor.setSelectedBufferRange([[1, 2], [3, 0]])
          editor.copySelectedText()

          editor.setCursorBufferPosition([5, 6])
          editor.pasteText()

          expect(editor.lineTextForBufferRow(5)).toBe "      var sort = function(items) {"
          expect(editor.lineTextForBufferRow(6)).toBe "        if (items.length <= 1) return items;"

      describe "when the cursor is indented less far than the original copied text", ->
        it "decreases the indentation of the copied lines to match", ->
          editor.setSelectedBufferRange([[6, 6], [8, 0]])
          editor.copySelectedText()

          editor.setCursorBufferPosition([1, 2])
          editor.pasteText()

          expect(editor.lineTextForBufferRow(1)).toBe "  current < pivot ? left.push(current) : right.push(current);"
          expect(editor.lineTextForBufferRow(2)).toBe "}"

      describe "when the first copied line has leading whitespace", ->
        it "preserves the line's leading whitespace", ->
          editor.setSelectedBufferRange([[4, 0], [6, 0]])
          editor.copySelectedText()

          editor.setCursorBufferPosition([0, 0])
          editor.pasteText()

          expect(editor.lineTextForBufferRow(0)).toBe "    while(items.length > 0) {"
          expect(editor.lineTextForBufferRow(1)).toBe "      current = items.shift();"

    describe 'when the clipboard has many selections', ->
      beforeEach ->
        editor.update({autoIndentOnPaste: false})
        editor.setSelectedBufferRanges([[[0, 4], [0, 13]], [[1, 6], [1, 10]]])
        editor.copySelectedText()

      it "pastes each selection in order separately into the buffer", ->
        editor.setSelectedBufferRanges([
          [[1, 6], [1, 10]]
          [[0, 4], [0, 13]],
        ])

        editor.moveRight()
        editor.insertText("_")
        editor.pasteText()
        expect(editor.lineTextForBufferRow(0)).toBe "var quicksort_quicksort = function () {"
        expect(editor.lineTextForBufferRow(1)).toBe "  var sort_sort = function(items) {"

      describe 'and the selections count does not match', ->
        beforeEach ->
          editor.setSelectedBufferRanges([[[0, 4], [0, 13]]])

        it "pastes the whole text into the buffer", ->
          editor.pasteText()
          expect(editor.lineTextForBufferRow(0)).toBe "var quicksort"
          expect(editor.lineTextForBufferRow(1)).toBe "sort = function () {"

    describe "when a full line was cut", ->
      beforeEach ->
        editor.setCursorBufferPosition([2, 13])
        editor.cutSelectedText()
        editor.setCursorBufferPosition([2, 13])

      it "pastes the line above the cursor and retains the cursor's column", ->
        editor.pasteText()
        expect(editor.lineTextForBufferRow(2)).toBe("    if (items.length <= 1) return items;")
        expect(editor.lineTextForBufferRow(3)).toBe("    var pivot = items.shift(), current, left = [], right = [];")
        expect(editor.getCursorBufferPosition()).toEqual([3, 13])

    describe "when a full line was copied", ->
      beforeEach ->
        editor.setCursorBufferPosition([2, 13])
        editor.copySelectedText()

      describe "when there is a selection", ->
        it "overwrites the selection as with any copied text", ->
          editor.setSelectedBufferRange([[1, 2], [1, Infinity]])
          editor.pasteText()
          expect(editor.lineTextForBufferRow(1)).toBe("  if (items.length <= 1) return items;")
          expect(editor.lineTextForBufferRow(2)).toBe("")
          expect(editor.lineTextForBufferRow(3)).toBe("    if (items.length <= 1) return items;")
          expect(editor.getCursorBufferPosition()).toEqual([2, 0])

      describe "when there is no selection", ->
        it "pastes the line above the cursor and retains the cursor's column", ->
          editor.pasteText()
          expect(editor.lineTextForBufferRow(2)).toBe("    if (items.length <= 1) return items;")
          expect(editor.lineTextForBufferRow(3)).toBe("    if (items.length <= 1) return items;")
          expect(editor.getCursorBufferPosition()).toEqual([3, 13])
