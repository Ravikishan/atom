path = require 'path'
TextEditor = require '../src/text-editor'
TextBuffer = require 'text-buffer'

describe "TextEditor", ->
  [buffer, editor] = []

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

  describe "when the editor is deserialized", ->
    it "restores selections and folds based on markers in the buffer", ->
      editor.setSelectedBufferRange([[1, 2], [3, 4]])
      editor.addSelectionForBufferRange([[5, 6], [7, 5]], reversed: true)
      editor.foldBufferRow(4)
      expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()

      editor2 = TextEditor.deserialize(editor.serialize(), atom)

      expect(editor2.id).toBe editor.id
      expect(editor2.getBuffer().getPath()).toBe editor.getBuffer().getPath()
      expect(editor2.getSelectedBufferRanges()).toEqual [[[1, 2], [3, 4]], [[5, 6], [7, 5]]]
      expect(editor2.getSelections()[1].isReversed()).toBeTruthy()
      expect(editor2.isFoldedAtBufferRow(4)).toBeTruthy()
      editor2.destroy()

    it "restores the editor's layout configuration", ->
      editor.update({
        softTabs: true
        atomicSoftTabs: false
        tabLength: 12
        softWrapped: true
        softWrapAtPreferredLineLength: true
        softWrapHangingIndentLength: 8
        invisibles: {space: 'S'}
        showInvisibles: true
        editorWidthInChars: 120
      })

      # Force buffer and display layer to be deserialized as well, rather than
      # reusing the same buffer instance
      editor2 = TextEditor.deserialize(editor.serialize(), {
        assert: atom.assert,
        textEditors: atom.textEditors,
        project: {
          bufferForIdSync: (id) -> TextBuffer.deserialize(editor.buffer.serialize())
        }
      })

      expect(editor2.getSoftTabs()).toBe(editor.getSoftTabs())
      expect(editor2.hasAtomicSoftTabs()).toBe(editor.hasAtomicSoftTabs())
      expect(editor2.getTabLength()).toBe(editor.getTabLength())
      expect(editor2.getSoftWrapColumn()).toBe(editor.getSoftWrapColumn())
      expect(editor2.getSoftWrapHangingIndentLength()).toBe(editor.getSoftWrapHangingIndentLength())
      expect(editor2.getInvisibles()).toEqual(editor.getInvisibles())
      expect(editor2.getEditorWidthInChars()).toBe(editor.getEditorWidthInChars())
      expect(editor2.displayLayer.tabLength).toBe(editor2.getTabLength())

  describe "when the editor is constructed with the largeFileMode option set to true", ->
    it "loads the editor but doesn't tokenize", ->
      editor = null

      waitsForPromise ->
        atom.workspace.openTextFile('sample.js', largeFileMode: true).then (o) -> editor = o

      runs ->
        buffer = editor.getBuffer()
        expect(editor.lineTextForScreenRow(0)).toBe buffer.lineForRow(0)
        expect(editor.tokensForScreenRow(0).length).toBe 1
        expect(editor.tokensForScreenRow(1).length).toBe 2 # soft tab
        expect(editor.lineTextForScreenRow(12)).toBe buffer.lineForRow(12)
        expect(editor.getCursorScreenPosition()).toEqual [0, 0]
        editor.insertText('hey"')
        expect(editor.tokensForScreenRow(0).length).toBe 1
        expect(editor.tokensForScreenRow(1).length).toBe 2 # soft tab

  describe ".copy()", ->
    it "returns a different editor with the same initial state", ->
      editor.update({autoHeight: false, autoWidth: true})
      editor.setSelectedBufferRange([[1, 2], [3, 4]])
      editor.addSelectionForBufferRange([[5, 6], [7, 8]], reversed: true)
      editor.firstVisibleScreenRow = 5
      editor.firstVisibleScreenColumn = 5
      editor.foldBufferRow(4)
      expect(editor.isFoldedAtBufferRow(4)).toBeTruthy()

      editor2 = editor.copy()
      expect(editor2.id).not.toBe editor.id
      expect(editor2.getSelectedBufferRanges()).toEqual editor.getSelectedBufferRanges()
      expect(editor2.getSelections()[1].isReversed()).toBeTruthy()
      expect(editor2.getFirstVisibleScreenRow()).toBe 5
      expect(editor2.getFirstVisibleScreenColumn()).toBe 5
      expect(editor2.isFoldedAtBufferRow(4)).toBeTruthy()
      expect(editor2.getAutoWidth()).toBeTruthy()
      expect(editor2.getAutoHeight()).toBeFalsy()

      # editor2 can now diverge from its origin edit session
      editor2.getLastSelection().setBufferRange([[2, 1], [4, 3]])
      expect(editor2.getSelectedBufferRanges()).not.toEqual editor.getSelectedBufferRanges()
      editor2.unfoldBufferRow(4)
      expect(editor2.isFoldedAtBufferRow(4)).not.toBe editor.isFoldedAtBufferRow(4)

  describe ".update()", ->
    it "updates the editor with the supplied config parameters", ->
      element = editor.element # force element initialization
      element.setUpdatedSynchronously(false)
      editor.update({showInvisibles: true})
      editor.onDidChange(changeSpy = jasmine.createSpy('onDidChange'))

      returnedPromise = editor.update({
        tabLength: 6, softTabs: false, softWrapped: true, editorWidthInChars: 40,
        showInvisibles: false, mini: false, lineNumberGutterVisible: false, scrollPastEnd: true,
        autoHeight: false
      })

      expect(returnedPromise).toBe(atom.views.getNextUpdatePromise())
      expect(changeSpy.callCount).toBe(1)
      expect(editor.getTabLength()).toBe(6)
      expect(editor.getSoftTabs()).toBe(false)
      expect(editor.isSoftWrapped()).toBe(true)
      expect(editor.getEditorWidthInChars()).toBe(40)
      expect(editor.getInvisibles()).toEqual({})
      expect(editor.isMini()).toBe(false)
      expect(editor.isLineNumberGutterVisible()).toBe(false)
      expect(editor.getScrollPastEnd()).toBe(true)
      expect(editor.getAutoHeight()).toBe(false)

  describe "title", ->
    describe ".getTitle()", ->
      it "uses the basename of the buffer's path as its title, or 'untitled' if the path is undefined", ->
        expect(editor.getTitle()).toBe 'sample.js'
        buffer.setPath(undefined)
        expect(editor.getTitle()).toBe 'untitled'

    describe ".getLongTitle()", ->
      it "returns file name when there is no opened file with identical name", ->
        expect(editor.getLongTitle()).toBe 'sample.js'
        buffer.setPath(undefined)
        expect(editor.getLongTitle()).toBe 'untitled'

      it "returns '<filename> — <parent-directory>' when opened files have identical file names", ->
        editor1 = null
        editor2 = null
        waitsForPromise ->
          atom.workspace.open(path.join('sample-theme-1', 'readme')).then (o) ->
            editor1 = o
            atom.workspace.open(path.join('sample-theme-2', 'readme')).then (o) ->
              editor2 = o
        runs ->
          expect(editor1.getLongTitle()).toBe "readme \u2014 sample-theme-1"
          expect(editor2.getLongTitle()).toBe "readme \u2014 sample-theme-2"

      it "returns '<filename> — <parent-directories>' when opened files have identical file names in subdirectories", ->
        editor1 = null
        editor2 = null
        path1 = path.join('sample-theme-1', 'src', 'js')
        path2 = path.join('sample-theme-2', 'src', 'js')
        waitsForPromise ->
          atom.workspace.open(path.join(path1, 'main.js')).then (o) ->
            editor1 = o
            atom.workspace.open(path.join(path2, 'main.js')).then (o) ->
              editor2 = o
        runs ->
          expect(editor1.getLongTitle()).toBe "main.js \u2014 #{path1}"
          expect(editor2.getLongTitle()).toBe "main.js \u2014 #{path2}"

      it "returns '<filename> — <parent-directories>' when opened files have identical file and same parent dir name", ->
        editor1 = null
        editor2 = null
        waitsForPromise ->
          atom.workspace.open(path.join('sample-theme-2', 'src', 'js', 'main.js')).then (o) ->
            editor1 = o
            atom.workspace.open(path.join('sample-theme-2', 'src', 'js', 'plugin', 'main.js')).then (o) ->
              editor2 = o
        runs ->
          expect(editor1.getLongTitle()).toBe "main.js \u2014 js"
          expect(editor2.getLongTitle()).toBe "main.js \u2014 " + path.join('js', 'plugin')

    it "notifies ::onDidChangeTitle observers when the underlying buffer path changes", ->
      observed = []
      editor.onDidChangeTitle (title) -> observed.push(title)

      buffer.setPath('/foo/bar/baz.txt')
      buffer.setPath(undefined)

      expect(observed).toEqual ['baz.txt', 'untitled']

  describe "path", ->
    it "notifies ::onDidChangePath observers when the underlying buffer path changes", ->
      observed = []
      editor.onDidChangePath (filePath) -> observed.push(filePath)

      buffer.setPath(__filename)
      buffer.setPath(undefined)

      expect(observed).toEqual [__filename, undefined]

  describe "encoding", ->
    it "notifies ::onDidChangeEncoding observers when the editor encoding changes", ->
      observed = []
      editor.onDidChangeEncoding (encoding) -> observed.push(encoding)

      editor.setEncoding('utf16le')
      editor.setEncoding('utf16le')
      editor.setEncoding('utf16be')
      editor.setEncoding()
      editor.setEncoding()

      expect(observed).toEqual ['utf16le', 'utf16be', 'utf8']

  describe "selection", ->
    selection = null

    beforeEach ->
      selection = editor.getLastSelection()

    describe ".getLastSelection()", ->
      it "creates a new selection at (0, 0) if the last selection has been destroyed", ->
        editor.getLastSelection().destroy()
        expect(editor.getLastSelection().getBufferRange()).toEqual([[0, 0], [0, 0]])

    describe ".getSelections()", ->
      it "creates a new selection at (0, 0) if the last selection has been destroyed", ->
        editor.getLastSelection().destroy()
        expect(editor.getSelections()[0].getBufferRange()).toEqual([[0, 0], [0, 0]])

    describe "when the selection range changes", ->
      it "emits an event with the old range, new range, and the selection that moved", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])

        editor.onDidChangeSelectionRange rangeChangedHandler = jasmine.createSpy()
        editor.selectToBufferPosition([6, 2])

        expect(rangeChangedHandler).toHaveBeenCalled()
        eventObject = rangeChangedHandler.mostRecentCall.args[0]

        expect(eventObject.oldBufferRange).toEqual [[3, 0], [4, 5]]
        expect(eventObject.oldScreenRange).toEqual [[3, 0], [4, 5]]
        expect(eventObject.newBufferRange).toEqual [[3, 0], [6, 2]]
        expect(eventObject.newScreenRange).toEqual [[3, 0], [6, 2]]
        expect(eventObject.selection).toBe selection

    describe ".selectUp/Down/Left/Right()", ->
      it "expands each selection to its cursor's new location", ->
        editor.setSelectedBufferRanges([[[0, 9], [0, 13]], [[3, 16], [3, 21]]])
        [selection1, selection2] = editor.getSelections()

        editor.selectRight()
        expect(selection1.getBufferRange()).toEqual [[0, 9], [0, 14]]
        expect(selection2.getBufferRange()).toEqual [[3, 16], [3, 22]]

        editor.selectLeft()
        editor.selectLeft()
        expect(selection1.getBufferRange()).toEqual [[0, 9], [0, 12]]
        expect(selection2.getBufferRange()).toEqual [[3, 16], [3, 20]]

        editor.selectDown()
        expect(selection1.getBufferRange()).toEqual [[0, 9], [1, 12]]
        expect(selection2.getBufferRange()).toEqual [[3, 16], [4, 20]]

        editor.selectUp()
        expect(selection1.getBufferRange()).toEqual [[0, 9], [0, 12]]
        expect(selection2.getBufferRange()).toEqual [[3, 16], [3, 20]]

      it "merges selections when they intersect when moving down", ->
        editor.setSelectedBufferRanges([[[0, 9], [0, 13]], [[1, 10], [1, 20]], [[2, 15], [3, 25]]])
        [selection1, selection2, selection3] = editor.getSelections()

        editor.selectDown()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 9], [4, 25]])
        expect(selection1.isReversed()).toBeFalsy()

      it "merges selections when they intersect when moving up", ->
        editor.setSelectedBufferRanges([[[0, 9], [0, 13]], [[1, 10], [1, 20]]], reversed: true)
        [selection1, selection2] = editor.getSelections()

        editor.selectUp()
        expect(editor.getSelections().length).toBe 1
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 0], [1, 20]])
        expect(selection1.isReversed()).toBeTruthy()

      it "merges selections when they intersect when moving left", ->
        editor.setSelectedBufferRanges([[[0, 9], [0, 13]], [[0, 13], [1, 20]]], reversed: true)
        [selection1, selection2] = editor.getSelections()

        editor.selectLeft()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 8], [1, 20]])
        expect(selection1.isReversed()).toBeTruthy()

      it "merges selections when they intersect when moving right", ->
        editor.setSelectedBufferRanges([[[0, 9], [0, 14]], [[0, 14], [1, 20]]])
        [selection1, selection2] = editor.getSelections()

        editor.selectRight()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.getScreenRange()).toEqual([[0, 9], [1, 21]])
        expect(selection1.isReversed()).toBeFalsy()

      describe "when counts are passed into the selection functions", ->
        it "expands each selection to its cursor's new location", ->
          editor.setSelectedBufferRanges([[[0, 9], [0, 13]], [[3, 16], [3, 21]]])
          [selection1, selection2] = editor.getSelections()

          editor.selectRight(2)
          expect(selection1.getBufferRange()).toEqual [[0, 9], [0, 15]]
          expect(selection2.getBufferRange()).toEqual [[3, 16], [3, 23]]

          editor.selectLeft(3)
          expect(selection1.getBufferRange()).toEqual [[0, 9], [0, 12]]
          expect(selection2.getBufferRange()).toEqual [[3, 16], [3, 20]]

          editor.selectDown(3)
          expect(selection1.getBufferRange()).toEqual [[0, 9], [3, 12]]
          expect(selection2.getBufferRange()).toEqual [[3, 16], [6, 20]]

          editor.selectUp(2)
          expect(selection1.getBufferRange()).toEqual [[0, 9], [1, 12]]
          expect(selection2.getBufferRange()).toEqual [[3, 16], [4, 20]]

    describe ".selectToBufferPosition(bufferPosition)", ->
      it "expands the last selection to the given position", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtBufferPosition([5, 6])
        editor.selectToBufferPosition([6, 2])

        selections = editor.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getBufferRange()).toEqual [[3, 0], [4, 5]]
        expect(selection2.getBufferRange()).toEqual [[5, 6], [6, 2]]

    describe ".selectToScreenPosition(screenPosition)", ->
      it "expands the last selection to the given position", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtScreenPosition([5, 6])
        editor.selectToScreenPosition([6, 2])

        selections = editor.getSelections()
        expect(selections.length).toBe 2
        [selection1, selection2] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 0], [4, 5]]
        expect(selection2.getScreenRange()).toEqual [[5, 6], [6, 2]]

      describe "when selecting with an initial screen range", ->
        it "switches the direction of the selection when selecting to positions before/after the start of the initial range", ->
          editor.setCursorScreenPosition([5, 10])
          editor.selectWordsContainingCursors()
          editor.selectToScreenPosition([3, 0])
          expect(editor.getLastSelection().isReversed()).toBe true
          editor.selectToScreenPosition([9, 0])
          expect(editor.getLastSelection().isReversed()).toBe false

    describe ".selectToBeginningOfNextParagraph()", ->
      it "selects from the cursor to first line of the next paragraph", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtScreenPosition([5, 6])
        editor.selectToScreenPosition([6, 2])

        editor.selectToBeginningOfNextParagraph()

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        expect(selections[0].getScreenRange()).toEqual [[3, 0], [10, 0]]

    describe ".selectToBeginningOfPreviousParagraph()", ->
      it "selects from the cursor to the first line of the pevious paragraph", ->
        editor.setSelectedBufferRange([[3, 0], [4, 5]])
        editor.addCursorAtScreenPosition([5, 6])
        editor.selectToScreenPosition([6, 2])

        editor.selectToBeginningOfPreviousParagraph()

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        expect(selections[0].getScreenRange()).toEqual [[0, 0], [5, 6]]

      it "merges selections if they intersect, maintaining the directionality of the last selection", ->
        editor.setCursorScreenPosition([4, 10])
        editor.selectToScreenPosition([5, 27])
        editor.addCursorAtScreenPosition([3, 10])
        editor.selectToScreenPosition([6, 27])

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        [selection1] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 10], [6, 27]]
        expect(selection1.isReversed()).toBeFalsy()

        editor.addCursorAtScreenPosition([7, 4])
        editor.selectToScreenPosition([4, 11])

        selections = editor.getSelections()
        expect(selections.length).toBe 1
        [selection1] = selections
        expect(selection1.getScreenRange()).toEqual [[3, 10], [7, 4]]
        expect(selection1.isReversed()).toBeTruthy()

    describe ".selectToTop()", ->
      it "selects text from cusor position to the top of the buffer", ->
        editor.setCursorScreenPosition [11, 2]
        editor.addCursorAtScreenPosition [10, 0]
        editor.selectToTop()
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursorBufferPosition()).toEqual [0, 0]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[0, 0], [11, 2]]
        expect(editor.getLastSelection().isReversed()).toBeTruthy()

    describe ".selectToBottom()", ->
      it "selects text from cusor position to the bottom of the buffer", ->
        editor.setCursorScreenPosition [10, 0]
        editor.addCursorAtScreenPosition [9, 3]
        editor.selectToBottom()
        expect(editor.getCursors().length).toBe 1
        expect(editor.getCursorBufferPosition()).toEqual [12, 2]
        expect(editor.getLastSelection().getBufferRange()).toEqual [[9, 3], [12, 2]]
        expect(editor.getLastSelection().isReversed()).toBeFalsy()

    describe ".selectAll()", ->
      it "selects the entire buffer", ->
        editor.selectAll()
        expect(editor.getLastSelection().getBufferRange()).toEqual buffer.getRange()

    describe ".selectToBeginningOfLine()", ->
      it "selects text from cusor position to beginning of line", ->
        editor.setCursorScreenPosition [12, 2]
        editor.addCursorAtScreenPosition [11, 3]

        editor.selectToBeginningOfLine()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [12, 0]
        expect(cursor2.getBufferPosition()).toEqual [11, 0]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[12, 0], [12, 2]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[11, 0], [11, 3]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".selectToEndOfLine()", ->
      it "selects text from cusor position to end of line", ->
        editor.setCursorScreenPosition [12, 0]
        editor.addCursorAtScreenPosition [11, 3]

        editor.selectToEndOfLine()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [12, 2]
        expect(cursor2.getBufferPosition()).toEqual [11, 44]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[12, 0], [12, 2]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[11, 3], [11, 44]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectLinesContainingCursors()", ->
      it "selects to the entire line (including newlines) at given row", ->
        editor.setCursorScreenPosition([1, 2])
        editor.selectLinesContainingCursors()
        expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [2, 0]]
        expect(editor.getSelectedText()).toBe "  var sort = function(items) {\n"

        editor.setCursorScreenPosition([12, 2])
        editor.selectLinesContainingCursors()
        expect(editor.getSelectedBufferRange()).toEqual [[12, 0], [12, 2]]

        editor.setCursorBufferPosition([0, 2])
        editor.selectLinesContainingCursors()
        editor.selectLinesContainingCursors()
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [2, 0]]

      describe "when the selection spans multiple row", ->
        it "selects from the beginning of the first line to the last line", ->
          selection = editor.getLastSelection()
          selection.setBufferRange [[1, 10], [3, 20]]
          editor.selectLinesContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[1, 0], [4, 0]]

    describe ".selectToBeginningOfWord()", ->
      it "selects text from cusor position to beginning of word", ->
        editor.setCursorScreenPosition [0, 13]
        editor.addCursorAtScreenPosition [3, 49]

        editor.selectToBeginningOfWord()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 4]
        expect(cursor2.getBufferPosition()).toEqual [3, 47]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 4], [0, 13]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[3, 47], [3, 49]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".selectToEndOfWord()", ->
      it "selects text from cusor position to end of word", ->
        editor.setCursorScreenPosition [0, 4]
        editor.addCursorAtScreenPosition [3, 48]

        editor.selectToEndOfWord()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 13]
        expect(cursor2.getBufferPosition()).toEqual [3, 50]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 4], [0, 13]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[3, 48], [3, 50]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectToBeginningOfNextWord()", ->
      it "selects text from cusor position to beginning of next word", ->
        editor.setCursorScreenPosition [0, 4]
        editor.addCursorAtScreenPosition [3, 48]

        editor.selectToBeginningOfNextWord()

        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 14]
        expect(cursor2.getBufferPosition()).toEqual [3, 51]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 4], [0, 14]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[3, 48], [3, 51]]
        expect(selection2.isReversed()).toBeFalsy()

    describe ".selectToPreviousWordBoundary()", ->
      it "select to the previous word boundary", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [2, 0]
        editor.addCursorAtBufferPosition [3, 4]
        editor.addCursorAtBufferPosition [3, 14]

        editor.selectToPreviousWordBoundary()

        expect(editor.getSelections().length).toBe 4
        [selection1, selection2, selection3, selection4] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 8], [0, 4]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[2, 0], [1, 30]]
        expect(selection2.isReversed()).toBeTruthy()
        expect(selection3.getBufferRange()).toEqual [[3, 4], [3, 0]]
        expect(selection3.isReversed()).toBeTruthy()
        expect(selection4.getBufferRange()).toEqual [[3, 14], [3, 13]]
        expect(selection4.isReversed()).toBeTruthy()

    describe ".selectToNextWordBoundary()", ->
      it "select to the next word boundary", ->
        editor.setCursorBufferPosition [0, 8]
        editor.addCursorAtBufferPosition [2, 40]
        editor.addCursorAtBufferPosition [4, 0]
        editor.addCursorAtBufferPosition [3, 30]

        editor.selectToNextWordBoundary()

        expect(editor.getSelections().length).toBe 4
        [selection1, selection2, selection3, selection4] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 8], [0, 13]]
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual [[2, 40], [3, 0]]
        expect(selection2.isReversed()).toBeFalsy()
        expect(selection3.getBufferRange()).toEqual [[4, 0], [4, 4]]
        expect(selection3.isReversed()).toBeFalsy()
        expect(selection4.getBufferRange()).toEqual [[3, 30], [3, 31]]
        expect(selection4.isReversed()).toBeFalsy()

    describe ".selectToPreviousSubwordBoundary", ->
      it "selects subwords", ->
        editor.setText("")
        editor.insertText("_word\n")
        editor.insertText(" getPreviousWord\n")
        editor.insertText("e, => \n")
        editor.insertText(" 88 \n")
        editor.setCursorBufferPosition([0, 5])
        editor.addCursorAtBufferPosition([1, 7])
        editor.addCursorAtBufferPosition([2, 5])
        editor.addCursorAtBufferPosition([3, 3])
        [selection1, selection2, selection3, selection4] = editor.getSelections()

        editor.selectToPreviousSubwordBoundary()
        expect(selection1.getBufferRange()).toEqual([[0, 1], [0, 5]])
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual([[1, 4], [1, 7]])
        expect(selection2.isReversed()).toBeTruthy()
        expect(selection3.getBufferRange()).toEqual([[2, 3], [2, 5]])
        expect(selection3.isReversed()).toBeTruthy()
        expect(selection4.getBufferRange()).toEqual([[3, 1], [3, 3]])
        expect(selection4.isReversed()).toBeTruthy()

    describe ".selectToNextSubwordBoundary", ->
      it "selects subwords", ->
        editor.setText("")
        editor.insertText("word_\n")
        editor.insertText("getPreviousWord\n")
        editor.insertText("e, => \n")
        editor.insertText(" 88 \n")
        editor.setCursorBufferPosition([0, 1])
        editor.addCursorAtBufferPosition([1, 7])
        editor.addCursorAtBufferPosition([2, 2])
        editor.addCursorAtBufferPosition([3, 1])
        [selection1, selection2, selection3, selection4] = editor.getSelections()

        editor.selectToNextSubwordBoundary()
        expect(selection1.getBufferRange()).toEqual([[0, 1], [0, 4]])
        expect(selection1.isReversed()).toBeFalsy()
        expect(selection2.getBufferRange()).toEqual([[1, 7], [1, 11]])
        expect(selection2.isReversed()).toBeFalsy()
        expect(selection3.getBufferRange()).toEqual([[2, 2], [2, 5]])
        expect(selection3.isReversed()).toBeFalsy()
        expect(selection4.getBufferRange()).toEqual([[3, 1], [3, 3]])
        expect(selection4.isReversed()).toBeFalsy()

    describe ".deleteToBeginningOfSubword", ->
      it "deletes subwords", ->
        editor.setText("")
        editor.insertText("_word\n")
        editor.insertText(" getPreviousWord\n")
        editor.insertText("e, => \n")
        editor.insertText(" 88 \n")
        editor.setCursorBufferPosition([0, 5])
        editor.addCursorAtBufferPosition([1, 7])
        editor.addCursorAtBufferPosition([2, 5])
        editor.addCursorAtBufferPosition([3, 3])
        [cursor1, cursor2, cursor3, cursor4] = editor.getCursors()

        editor.deleteToBeginningOfSubword()
        expect(buffer.lineForRow(0)).toBe('_')
        expect(buffer.lineForRow(1)).toBe(' getviousWord')
        expect(buffer.lineForRow(2)).toBe('e,  ')
        expect(buffer.lineForRow(3)).toBe('  ')
        expect(cursor1.getBufferPosition()).toEqual([0, 1])
        expect(cursor2.getBufferPosition()).toEqual([1, 4])
        expect(cursor3.getBufferPosition()).toEqual([2, 3])
        expect(cursor4.getBufferPosition()).toEqual([3, 1])

        editor.deleteToBeginningOfSubword()
        expect(buffer.lineForRow(0)).toBe('')
        expect(buffer.lineForRow(1)).toBe(' viousWord')
        expect(buffer.lineForRow(2)).toBe('e ')
        expect(buffer.lineForRow(3)).toBe(' ')
        expect(cursor1.getBufferPosition()).toEqual([0, 0])
        expect(cursor2.getBufferPosition()).toEqual([1, 1])
        expect(cursor3.getBufferPosition()).toEqual([2, 1])
        expect(cursor4.getBufferPosition()).toEqual([3, 0])

        editor.deleteToBeginningOfSubword()
        expect(buffer.lineForRow(0)).toBe('')
        expect(buffer.lineForRow(1)).toBe('viousWord')
        expect(buffer.lineForRow(2)).toBe('  ')
        expect(buffer.lineForRow(3)).toBe('')
        expect(cursor1.getBufferPosition()).toEqual([0, 0])
        expect(cursor2.getBufferPosition()).toEqual([1, 0])
        expect(cursor3.getBufferPosition()).toEqual([2, 0])
        expect(cursor4.getBufferPosition()).toEqual([2, 1])

    describe ".deleteToEndOfSubword", ->
      it "deletes subwords", ->
        editor.setText("")
        editor.insertText("word_\n")
        editor.insertText("getPreviousWord \n")
        editor.insertText("e, => \n")
        editor.insertText(" 88 \n")
        editor.setCursorBufferPosition([0, 0])
        editor.addCursorAtBufferPosition([1, 0])
        editor.addCursorAtBufferPosition([2, 2])
        editor.addCursorAtBufferPosition([3, 0])
        [cursor1, cursor2, cursor3, cursor4] = editor.getCursors()

        editor.deleteToEndOfSubword()
        expect(buffer.lineForRow(0)).toBe('_')
        expect(buffer.lineForRow(1)).toBe('PreviousWord ')
        expect(buffer.lineForRow(2)).toBe('e, ')
        expect(buffer.lineForRow(3)).toBe('88 ')
        expect(cursor1.getBufferPosition()).toEqual([0, 0])
        expect(cursor2.getBufferPosition()).toEqual([1, 0])
        expect(cursor3.getBufferPosition()).toEqual([2, 2])
        expect(cursor4.getBufferPosition()).toEqual([3, 0])

        editor.deleteToEndOfSubword()
        expect(buffer.lineForRow(0)).toBe('')
        expect(buffer.lineForRow(1)).toBe('Word ')
        expect(buffer.lineForRow(2)).toBe('e,')
        expect(buffer.lineForRow(3)).toBe(' ')
        expect(cursor1.getBufferPosition()).toEqual([0, 0])
        expect(cursor2.getBufferPosition()).toEqual([1, 0])
        expect(cursor3.getBufferPosition()).toEqual([2, 2])
        expect(cursor4.getBufferPosition()).toEqual([3, 0])

    describe ".selectWordsContainingCursors()", ->
      describe "when the cursor is inside a word", ->
        it "selects the entire word", ->
          editor.setCursorScreenPosition([0, 8])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedText()).toBe 'quicksort'

      describe "when the cursor is between two words", ->
        it "selects the word the cursor is on", ->
          editor.setCursorScreenPosition([0, 4])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedText()).toBe 'quicksort'

          editor.setCursorScreenPosition([0, 3])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedText()).toBe 'var'

      describe "when the cursor is inside a region of whitespace", ->
        it "selects the whitespace region", ->
          editor.setCursorScreenPosition([5, 2])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[5, 0], [5, 6]]

          editor.setCursorScreenPosition([5, 0])
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[5, 0], [5, 6]]

      describe "when the cursor is at the end of the text", ->
        it "select the previous word", ->
          editor.buffer.append 'word'
          editor.moveToBottom()
          editor.selectWordsContainingCursors()
          expect(editor.getSelectedBufferRange()).toEqual [[12, 2], [12, 6]]

      it "selects words based on the non-word characters configured at the cursor's current scope", ->
        editor.setText("one-one; 'two-two'; three-three")

        editor.setCursorBufferPosition([0, 1])
        editor.addCursorAtBufferPosition([0, 12])

        scopeDescriptors = editor.getCursors().map (c) -> c.getScopeDescriptor()
        expect(scopeDescriptors[0].getScopesArray()).toEqual(['source.js'])
        expect(scopeDescriptors[1].getScopesArray()).toEqual(['source.js', 'string.quoted.single.js'])

        editor.setScopedSettingsDelegate({
          getNonWordCharacters: (scopes) ->
            result = '/\()"\':,.;<>~!@#$%^&*|+=[]{}`?'
            if (scopes.some (scope) -> scope.startsWith('string'))
              result
            else
              result + '-'
        })

        editor.selectWordsContainingCursors()

        expect(editor.getSelections()[0].getText()).toBe('one')
        expect(editor.getSelections()[1].getText()).toBe('two-two')

    describe ".selectToFirstCharacterOfLine()", ->
      it "moves to the first character of the current line or the beginning of the line if it's already on the first character", ->
        editor.setCursorScreenPosition [0, 5]
        editor.addCursorAtScreenPosition [1, 7]

        editor.selectToFirstCharacterOfLine()

        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 0]
        expect(cursor2.getBufferPosition()).toEqual [1, 2]

        expect(editor.getSelections().length).toBe 2
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 0], [0, 5]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[1, 2], [1, 7]]
        expect(selection2.isReversed()).toBeTruthy()

        editor.selectToFirstCharacterOfLine()
        [selection1, selection2] = editor.getSelections()
        expect(selection1.getBufferRange()).toEqual [[0, 0], [0, 5]]
        expect(selection1.isReversed()).toBeTruthy()
        expect(selection2.getBufferRange()).toEqual [[1, 0], [1, 7]]
        expect(selection2.isReversed()).toBeTruthy()

    describe ".setSelectedBufferRanges(ranges)", ->
      it "clears existing selections and creates selections for each of the given ranges", ->
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [3, 3]], [[4, 4], [5, 5]]]

        editor.setSelectedBufferRanges([[[5, 5], [6, 6]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[5, 5], [6, 6]]]

      it "merges intersecting selections", ->
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [5, 5]]]

      it "does not merge non-empty adjacent selections", ->
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 3], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [3, 3]], [[3, 3], [5, 5]]]

      it "recyles existing selection instances", ->
        selection = editor.getLastSelection()
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[4, 4], [5, 5]]])

        [selection1, selection2] = editor.getSelections()
        expect(selection1).toBe selection
        expect(selection1.getBufferRange()).toEqual [[2, 2], [3, 3]]

      describe "when the 'preserveFolds' option is false (the default)", ->
        it "removes folds that contain the selections", ->
          editor.setSelectedBufferRange([[0, 0], [0, 0]])
          editor.foldBufferRowRange(1, 4)
          editor.foldBufferRowRange(2, 3)
          editor.foldBufferRowRange(6, 8)
          editor.foldBufferRowRange(10, 11)

          editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 6], [7, 7]]])
          expect(editor.isFoldedAtScreenRow(1)).toBeFalsy()
          expect(editor.isFoldedAtScreenRow(2)).toBeFalsy()
          expect(editor.isFoldedAtScreenRow(6)).toBeFalsy()
          expect(editor.isFoldedAtScreenRow(10)).toBeTruthy()

      describe "when the 'preserveFolds' option is true", ->
        it "does not remove folds that contain the selections", ->
          editor.setSelectedBufferRange([[0, 0], [0, 0]])
          editor.foldBufferRowRange(1, 4)
          editor.foldBufferRowRange(6, 8)
          editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[6, 0], [6, 1]]], preserveFolds: true)
          expect(editor.isFoldedAtBufferRow(1)).toBeTruthy()
          expect(editor.isFoldedAtBufferRow(6)).toBeTruthy()

    describe ".setSelectedScreenRanges(ranges)", ->
      beforeEach ->
        editor.foldBufferRow(4)

      it "clears existing selections and creates selections for each of the given ranges", ->
        editor.setSelectedScreenRanges([[[3, 4], [3, 7]], [[5, 4], [5, 7]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[3, 4], [3, 7]], [[8, 4], [8, 7]]]

        editor.setSelectedScreenRanges([[[6, 2], [6, 4]]])
        expect(editor.getSelectedScreenRanges()).toEqual [[[6, 2], [6, 4]]]

      it "merges intersecting selections and unfolds the fold which contain them", ->
        editor.foldBufferRow(0)

        # Use buffer ranges because only the first line is on screen
        editor.setSelectedBufferRanges([[[2, 2], [3, 3]], [[3, 0], [5, 5]]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[2, 2], [5, 5]]]

      it "recyles existing selection instances", ->
        selection = editor.getLastSelection()
        editor.setSelectedScreenRanges([[[2, 2], [3, 4]], [[4, 4], [5, 5]]])

        [selection1, selection2] = editor.getSelections()
        expect(selection1).toBe selection
        expect(selection1.getScreenRange()).toEqual [[2, 2], [3, 4]]

    describe ".selectMarker(marker)", ->
      describe "if the marker is valid", ->
        it "selects the marker's range and returns the selected range", ->
          marker = editor.markBufferRange([[0, 1], [3, 3]])
          expect(editor.selectMarker(marker)).toEqual [[0, 1], [3, 3]]
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [3, 3]]

      describe "if the marker is invalid", ->
        it "does not change the selection and returns a falsy value", ->
          marker = editor.markBufferRange([[0, 1], [3, 3]])
          marker.destroy()
          expect(editor.selectMarker(marker)).toBeFalsy()
          expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 0]]

    describe ".addSelectionForBufferRange(bufferRange)", ->
      it "adds a selection for the specified buffer range", ->
        editor.addSelectionForBufferRange([[3, 4], [5, 6]])
        expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [0, 0]], [[3, 4], [5, 6]]]

    describe ".addSelectionBelow()", ->
      describe "when the selection is non-empty", ->
        it "selects the same region of the line below current selections if possible", ->
          editor.setSelectedBufferRange([[3, 16], [3, 21]])
          editor.addSelectionForBufferRange([[3, 25], [3, 34]])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 16], [3, 21]]
            [[3, 25], [3, 34]]
            [[4, 16], [4, 21]]
            [[4, 25], [4, 29]]
          ]
          for cursor in editor.getCursors()
            expect(cursor.isVisible()).toBeFalsy()

        it "skips lines that are too short to create a non-empty selection", ->
          editor.setSelectedBufferRange([[3, 31], [3, 38]])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 31], [3, 38]]
            [[6, 31], [6, 38]]
          ]

        it "honors the original selection's range (goal range) when adding across shorter lines", ->
          editor.setSelectedBufferRange([[3, 22], [3, 38]])
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 22], [3, 38]]
            [[4, 22], [4, 29]]
            [[5, 22], [5, 30]]
            [[6, 22], [6, 38]]
          ]

        it "clears selection goal ranges when the selection changes", ->
          editor.setSelectedBufferRange([[3, 22], [3, 38]])
          editor.addSelectionBelow()
          editor.selectLeft()
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 22], [3, 37]]
            [[4, 22], [4, 29]]
            [[5, 22], [5, 28]]
          ]

          # goal range from previous add selection is honored next time
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 22], [3, 37]]
            [[4, 22], [4, 29]]
            [[5, 22], [5, 30]] # select to end of line 5 because line 4's goal range was reset by line 3 previously
            [[6, 22], [6, 28]]
          ]

        it "can add selections to soft-wrapped line segments", ->
          editor.setSoftWrapped(true)
          editor.setEditorWidthInChars(40)
          editor.setDefaultCharWidth(1)

          editor.setSelectedScreenRange([[3, 10], [3, 15]])
          editor.addSelectionBelow()
          expect(editor.getSelectedScreenRanges()).toEqual [
            [[3, 10], [3, 15]]
            [[4, 10], [4, 15]]
          ]

        it "takes atomic tokens into account", ->
          waitsForPromise ->
            atom.workspace.open('sample-with-tabs-and-leading-comment.coffee', autoIndent: false).then (o) -> editor = o

          runs ->
            editor.setSelectedBufferRange([[2, 1], [2, 3]])
            editor.addSelectionBelow()

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[2, 1], [2, 3]]
              [[3, 1], [3, 2]]
            ]

      describe "when the selection is empty", ->
        describe "when lines are soft-wrapped", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            editor.setDefaultCharWidth(1)
            editor.setEditorWidthInChars(40)

          it "skips soft-wrap indentation tokens", ->
            editor.setCursorScreenPosition([3, 0])
            editor.addSelectionBelow()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[3, 0], [3, 0]]
              [[4, 4], [4, 4]]
            ]

          it "does not skip them if they're shorter than the current column", ->
            editor.setCursorScreenPosition([3, 37])
            editor.addSelectionBelow()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[3, 37], [3, 37]]
              [[4, 26], [4, 26]]
            ]

        it "does not skip lines that are shorter than the current column", ->
          editor.setCursorBufferPosition([3, 36])
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 36], [3, 36]]
            [[4, 29], [4, 29]]
            [[5, 30], [5, 30]]
            [[6, 36], [6, 36]]
          ]

        it "skips empty lines when the column is non-zero", ->
          editor.setCursorBufferPosition([9, 4])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[9, 4], [9, 4]]
            [[11, 4], [11, 4]]
          ]

        it "does not skip empty lines when the column is zero", ->
          editor.setCursorBufferPosition([9, 0])
          editor.addSelectionBelow()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[9, 0], [9, 0]]
            [[10, 0], [10, 0]]
          ]

    describe ".addSelectionAbove()", ->
      describe "when the selection is non-empty", ->
        it "selects the same region of the line above current selections if possible", ->
          editor.setSelectedBufferRange([[3, 16], [3, 21]])
          editor.addSelectionForBufferRange([[3, 37], [3, 44]])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[3, 16], [3, 21]]
            [[3, 37], [3, 44]]
            [[2, 16], [2, 21]]
            [[2, 37], [2, 40]]
          ]
          for cursor in editor.getCursors()
            expect(cursor.isVisible()).toBeFalsy()

        it "skips lines that are too short to create a non-empty selection", ->
          editor.setSelectedBufferRange([[6, 31], [6, 38]])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[6, 31], [6, 38]]
            [[3, 31], [3, 38]]
          ]

        it "honors the original selection's range (goal range) when adding across shorter lines", ->
          editor.setSelectedBufferRange([[6, 22], [6, 38]])
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[6, 22], [6, 38]]
            [[5, 22], [5, 30]]
            [[4, 22], [4, 29]]
            [[3, 22], [3, 38]]
          ]

        it "can add selections to soft-wrapped line segments", ->
          editor.setSoftWrapped(true)
          editor.setDefaultCharWidth(1)
          editor.setEditorWidthInChars(40)

          editor.setSelectedScreenRange([[4, 10], [4, 15]])
          editor.addSelectionAbove()
          expect(editor.getSelectedScreenRanges()).toEqual [
            [[4, 10], [4, 15]]
            [[3, 10], [3, 15]]
          ]

        it "takes atomic tokens into account", ->
          waitsForPromise ->
            atom.workspace.open('sample-with-tabs-and-leading-comment.coffee', autoIndent: false).then (o) -> editor = o

          runs ->
            editor.setSelectedBufferRange([[3, 1], [3, 2]])
            editor.addSelectionAbove()

            expect(editor.getSelectedBufferRanges()).toEqual [
              [[3, 1], [3, 2]]
              [[2, 1], [2, 3]]
            ]

      describe "when the selection is empty", ->
        describe "when lines are soft-wrapped", ->
          beforeEach ->
            editor.setSoftWrapped(true)
            editor.setDefaultCharWidth(1)
            editor.setEditorWidthInChars(40)

          it "skips soft-wrap indentation tokens", ->
            editor.setCursorScreenPosition([5, 0])
            editor.addSelectionAbove()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[5, 0], [5, 0]]
              [[4, 4], [4, 4]]
            ]

          it "does not skip them if they're shorter than the current column", ->
            editor.setCursorScreenPosition([5, 29])
            editor.addSelectionAbove()

            expect(editor.getSelectedScreenRanges()).toEqual [
              [[5, 29], [5, 29]]
              [[4, 26], [4, 26]]
            ]

        it "does not skip lines that are shorter than the current column", ->
          editor.setCursorBufferPosition([6, 36])
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[6, 36], [6, 36]]
            [[5, 30], [5, 30]]
            [[4, 29], [4, 29]]
            [[3, 36], [3, 36]]
          ]

        it "skips empty lines when the column is non-zero", ->
          editor.setCursorBufferPosition([11, 4])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[11, 4], [11, 4]]
            [[9, 4], [9, 4]]
          ]

        it "does not skip empty lines when the column is zero", ->
          editor.setCursorBufferPosition([10, 0])
          editor.addSelectionAbove()
          expect(editor.getSelectedBufferRanges()).toEqual [
            [[10, 0], [10, 0]]
            [[9, 0], [9, 0]]
          ]

    describe ".splitSelectionsIntoLines()", ->
      it "splits all multi-line selections into one selection per line", ->
        editor.setSelectedBufferRange([[0, 3], [2, 4]])
        editor.splitSelectionsIntoLines()
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 3], [0, 29]]
          [[1, 0], [1, 30]]
          [[2, 0], [2, 4]]
        ]

        editor.setSelectedBufferRange([[0, 3], [1, 10]])
        editor.splitSelectionsIntoLines()
        expect(editor.getSelectedBufferRanges()).toEqual [
          [[0, 3], [0, 29]]
          [[1, 0], [1, 10]]
        ]

        editor.setSelectedBufferRange([[0, 0], [0, 3]])
        editor.splitSelectionsIntoLines()
        expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [0, 3]]]

    describe "::consolidateSelections()", ->
      makeMultipleSelections = ->
        selection.setBufferRange [[3, 16], [3, 21]]
        selection2 = editor.addSelectionForBufferRange([[3, 25], [3, 34]])
        selection3 = editor.addSelectionForBufferRange([[8, 4], [8, 10]])
        selection4 = editor.addSelectionForBufferRange([[1, 6], [1, 10]])
        expect(editor.getSelections()).toEqual [selection, selection2, selection3, selection4]
        [selection, selection2, selection3, selection4]

      it "destroys all selections but the oldest selection and autoscrolls to it, returning true if any selections were destroyed", ->
        [selection1] = makeMultipleSelections()

        autoscrollEvents = []
        editor.onDidRequestAutoscroll (event) -> autoscrollEvents.push(event)

        expect(editor.consolidateSelections()).toBeTruthy()
        expect(editor.getSelections()).toEqual [selection1]
        expect(selection1.isEmpty()).toBeFalsy()
        expect(editor.consolidateSelections()).toBeFalsy()
        expect(editor.getSelections()).toEqual [selection1]

        expect(autoscrollEvents).toEqual([
          {screenRange: selection1.getScreenRange(), options: {center: true, reversed: false}}
        ])

    describe "when the cursor is moved while there is a selection", ->
      makeSelection = -> selection.setBufferRange [[1, 2], [1, 5]]

      it "clears the selection", ->
        makeSelection()
        editor.moveDown()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.moveUp()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.moveLeft()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.moveRight()
        expect(selection.isEmpty()).toBeTruthy()

        makeSelection()
        editor.setCursorScreenPosition([3, 3])
        expect(selection.isEmpty()).toBeTruthy()

    it "does not share selections between different edit sessions for the same buffer", ->
      editor2 = null
      waitsForPromise ->
        atom.workspace.getActivePane().splitRight()
        atom.workspace.open(editor.getPath()).then (o) -> editor2 = o

      runs ->
        expect(editor2.getText()).toBe(editor.getText())
        editor.setSelectedBufferRanges([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
        editor2.setSelectedBufferRanges([[[8, 7], [6, 5]], [[4, 3], [2, 1]]])
        expect(editor2.getSelectedBufferRanges()).not.toEqual editor.getSelectedBufferRanges()

  describe 'reading text', ->
    it '.lineTextForScreenRow(row)', ->
      editor.foldBufferRow(4)
      expect(editor.lineTextForScreenRow(5)).toEqual '    return sort(left).concat(pivot).concat(sort(right));'
      expect(editor.lineTextForScreenRow(9)).toEqual '};'
      expect(editor.lineTextForScreenRow(10)).toBeUndefined()

  describe ".deleteLine()", ->
    it "deletes the first line when the cursor is there", ->
      editor.getLastCursor().moveToTop()
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line1)
      editor.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "deletes the last line when the cursor is there", ->
      count = buffer.getLineCount()
      secondToLastLine = buffer.lineForRow(count - 2)
      expect(buffer.lineForRow(count - 1)).not.toBe(secondToLastLine)
      editor.getLastCursor().moveToBottom()
      editor.deleteLine()
      newCount = buffer.getLineCount()
      expect(buffer.lineForRow(newCount - 1)).toBe(secondToLastLine)
      expect(newCount).toBe(count - 1)

    it "deletes whole lines when partial lines are selected", ->
      editor.setSelectedBufferRange([[0, 2], [1, 2]])
      line2 = buffer.lineForRow(2)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line2)
      expect(buffer.lineForRow(1)).not.toBe(line2)
      editor.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line2)
      expect(buffer.getLineCount()).toBe(count - 2)

    it "deletes a line only once when multiple selections are on the same line", ->
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      editor.setSelectedBufferRanges([
        [[0, 1], [0, 2]],
        [[0, 4], [0, 5]]
      ])
      expect(buffer.lineForRow(0)).not.toBe(line1)

      editor.deleteLine()

      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "only deletes first line if only newline is selected on second line", ->
      editor.setSelectedBufferRange([[0, 2], [1, 0]])
      line1 = buffer.lineForRow(1)
      count = buffer.getLineCount()
      expect(buffer.lineForRow(0)).not.toBe(line1)
      editor.deleteLine()
      expect(buffer.lineForRow(0)).toBe(line1)
      expect(buffer.getLineCount()).toBe(count - 1)

    it "deletes the entire region when invoke on a folded region", ->
      editor.foldBufferRow(1)
      editor.getLastCursor().moveToTop()
      editor.getLastCursor().moveDown()
      expect(buffer.getLineCount()).toBe(13)
      editor.deleteLine()
      expect(buffer.getLineCount()).toBe(4)

    it "deletes the entire file from the bottom up", ->
      count = buffer.getLineCount()
      expect(count).toBeGreaterThan(0)
      for [0...count]
        editor.getLastCursor().moveToBottom()
        editor.deleteLine()
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getText()).toBe('')

    it "deletes the entire file from the top down", ->
      count = buffer.getLineCount()
      expect(count).toBeGreaterThan(0)
      for [0...count]
        editor.getLastCursor().moveToTop()
        editor.deleteLine()
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getText()).toBe('')

    describe "when soft wrap is enabled", ->
      it "deletes the entire line that the cursor is on", ->
        editor.setSoftWrapped(true)
        editor.setEditorWidthInChars(10)
        editor.setCursorBufferPosition([6])

        line7 = buffer.lineForRow(7)
        count = buffer.getLineCount()
        expect(buffer.lineForRow(6)).not.toBe(line7)
        editor.deleteLine()
        expect(buffer.lineForRow(6)).toBe(line7)
        expect(buffer.getLineCount()).toBe(count - 1)

    describe "when the line being deleted preceeds a fold, and the command is undone", ->
      # TODO: This seemed to have only been passing due to an accident in the text
      # buffer implementation. Once we moved selections to a different layer it
      # broke. We need to revisit our representation of folds and then reenable it.
      xit "restores the line and preserves the fold", ->
        editor.setCursorBufferPosition([4])
        editor.foldCurrentRow()
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
        editor.setCursorBufferPosition([3])
        editor.deleteLine()
        expect(editor.isFoldedAtScreenRow(3)).toBeTruthy()
        expect(buffer.lineForRow(3)).toBe '    while(items.length > 0) {'
        editor.undo()
        expect(editor.isFoldedAtScreenRow(4)).toBeTruthy()
        expect(buffer.lineForRow(3)).toBe '    var pivot = items.shift(), current, left = [], right = [];'

  describe ".replaceSelectedText(options, fn)", ->
    describe "when no text is selected", ->
      it "inserts the text returned from the function at the cursor position", ->
        editor.replaceSelectedText {}, -> '123'
        expect(buffer.lineForRow(0)).toBe '123var quicksort = function () {'

        editor.replaceSelectedText {selectWordIfEmpty: true}, -> 'var'
        editor.setCursorBufferPosition([0])
        expect(buffer.lineForRow(0)).toBe 'var quicksort = function () {'

        editor.setCursorBufferPosition([10])
        editor.replaceSelectedText null, -> ''
        expect(buffer.lineForRow(10)).toBe ''

    describe "when text is selected", ->
      it "replaces the selected text with the text returned from the function", ->
        editor.setSelectedBufferRange([[0, 1], [0, 3]])
        editor.replaceSelectedText {}, -> 'ia'
        expect(buffer.lineForRow(0)).toBe 'via quicksort = function () {'

  describe ".transpose()", ->
    it "swaps two characters", ->
      editor.buffer.setText("abc")
      editor.setCursorScreenPosition([0, 1])
      editor.transpose()
      expect(editor.lineTextForBufferRow(0)).toBe 'bac'

    it "reverses a selection", ->
      editor.buffer.setText("xabcz")
      editor.setSelectedBufferRange([[0, 1], [0, 4]])
      editor.transpose()
      expect(editor.lineTextForBufferRow(0)).toBe 'xcbaz'

  describe ".upperCase()", ->
    describe "when there is no selection", ->
      it "upper cases the current word", ->
        editor.buffer.setText("aBc")
        editor.setCursorScreenPosition([0, 1])
        editor.upperCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'ABC'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is a selection", ->
      it "upper cases the current selection", ->
        editor.buffer.setText("abc")
        editor.setSelectedBufferRange([[0, 0], [0, 2]])
        editor.upperCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'ABc'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 2]]

  describe ".lowerCase()", ->
    describe "when there is no selection", ->
      it "lower cases the current word", ->
        editor.buffer.setText("aBC")
        editor.setCursorScreenPosition([0, 1])
        editor.lowerCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'abc'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 1]]

    describe "when there is a selection", ->
      it "lower cases the current selection", ->
        editor.buffer.setText("ABC")
        editor.setSelectedBufferRange([[0, 0], [0, 2]])
        editor.lowerCase()
        expect(editor.lineTextForBufferRow(0)).toBe 'abC'
        expect(editor.getSelectedBufferRange()).toEqual [[0, 0], [0, 2]]

  describe '.setTabLength(tabLength)', ->
    it 'retokenizes the editor with the given tab length', ->
      expect(editor.getTabLength()).toBe 2
      leadingWhitespaceTokens = editor.tokensForScreenRow(5).filter (token) -> 'leading-whitespace' in token.scopes
      expect(leadingWhitespaceTokens.length).toBe(3)

      editor.setTabLength(6)
      expect(editor.getTabLength()).toBe 6
      leadingWhitespaceTokens = editor.tokensForScreenRow(5).filter (token) -> 'leading-whitespace' in token.scopes
      expect(leadingWhitespaceTokens.length).toBe(1)

      changeHandler = jasmine.createSpy('changeHandler')
      editor.onDidChange(changeHandler)
      editor.setTabLength(6)
      expect(changeHandler).not.toHaveBeenCalled()

    it 'does not change its tab length when the given tab length is null', ->
      editor.setTabLength(4)
      editor.setTabLength(null)
      expect(editor.getTabLength()).toBe(4)

  describe ".indentLevelForLine(line)", ->
    it "returns the indent level when the line has only leading whitespace", ->
      expect(editor.indentLevelForLine("    hello")).toBe(2)
      expect(editor.indentLevelForLine("   hello")).toBe(1.5)

    it "returns the indent level when the line has only leading tabs", ->
      expect(editor.indentLevelForLine("\t\thello")).toBe(2)

    it "returns the indent level based on the character starting the line when the leading whitespace contains both spaces and tabs", ->
      expect(editor.indentLevelForLine("\t  hello")).toBe(2)
      expect(editor.indentLevelForLine("  \thello")).toBe(2)
      expect(editor.indentLevelForLine("  \t hello")).toBe(2.5)
      expect(editor.indentLevelForLine("    \t \thello")).toBe(4)
      expect(editor.indentLevelForLine("     \t \thello")).toBe(4)
      expect(editor.indentLevelForLine("     \t \t hello")).toBe(4.5)

  describe "when the buffer is reloaded", ->
    it "preserves the current cursor position", ->
      editor.setCursorScreenPosition([0, 1])
      editor.buffer.reload()
      expect(editor.getCursorScreenPosition()).toEqual [0, 1]

  describe "when a better-matched grammar is added to syntax", ->
    it "switches to the better-matched grammar and re-tokenizes the buffer", ->
      editor.destroy()

      jsGrammar = atom.grammars.selectGrammar('a.js')
      atom.grammars.removeGrammar(jsGrammar)

      waitsForPromise ->
        atom.workspace.open('sample.js', autoIndent: false).then (o) -> editor = o

      runs ->
        expect(editor.getGrammar()).toBe atom.grammars.nullGrammar
        expect(editor.tokensForScreenRow(0).length).toBe(1)

        atom.grammars.addGrammar(jsGrammar)
        expect(editor.getGrammar()).toBe jsGrammar
        expect(editor.tokensForScreenRow(0).length).toBeGreaterThan 1

  describe "editor.autoIndent", ->
    describe "when editor.autoIndent is false (default)", ->
      describe "when `indent` is triggered", ->
        it "does not auto-indent the line", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n ")
          expect(editor.lineTextForBufferRow(2)).toBe " "

          editor.update({autoIndent: false})
          editor.indent()
          expect(editor.lineTextForBufferRow(2)).toBe "  "

    describe "when editor.autoIndent is true", ->
      beforeEach ->
        editor.update({autoIndent: true})

      describe "when `indent` is triggered", ->
        it "auto-indents the line", ->
          editor.setCursorBufferPosition([1, 30])
          editor.insertText("\n ")
          expect(editor.lineTextForBufferRow(2)).toBe " "

          editor.update({autoIndent: true})
          editor.indent()
          expect(editor.lineTextForBufferRow(2)).toBe "    "

      describe "when a newline is added", ->
        describe "when the line preceding the newline adds a new level of indentation", ->
          it "indents the newline to one additional level of indentation beyond the preceding line", ->
            editor.setCursorBufferPosition([1, Infinity])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1

        describe "when the line preceding the newline does't add a level of indentation", ->
          it "indents the new line to the same level as the preceding line", ->
            editor.setCursorBufferPosition([5, 14])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(6)).toBe editor.indentationForBufferRow(5)

        describe "when the line preceding the newline is a comment", ->
          it "maintains the indent of the commented line", ->
            editor.setCursorBufferPosition([0, 0])
            editor.insertText('    //')
            editor.setCursorBufferPosition([0, Infinity])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(1)).toBe 2

        describe "when the line preceding the newline contains only whitespace", ->
          it "bases the new line's indentation on only the preceding line", ->
            editor.setCursorBufferPosition([6, Infinity])
            editor.insertText("\n  ")
            expect(editor.getCursorBufferPosition()).toEqual([7, 2])

            editor.insertNewline()
            expect(editor.lineTextForBufferRow(8)).toBe("  ")

        it "does not indent the line preceding the newline", ->
          editor.setCursorBufferPosition([2, 0])
          editor.insertText('  var this-line-should-be-indented-more\n')
          expect(editor.indentationForBufferRow(1)).toBe 1

          editor.update({autoIndent: true})
          editor.setCursorBufferPosition([2, Infinity])
          editor.insertText('\n')
          expect(editor.indentationForBufferRow(1)).toBe 1
          expect(editor.indentationForBufferRow(2)).toBe 1

        describe "when the cursor is before whitespace", ->
          it "retains the whitespace following the cursor on the new line", ->
            editor.setText("  var sort = function() {}")
            editor.setCursorScreenPosition([0, 12])
            editor.insertNewline()

            expect(buffer.lineForRow(0)).toBe '  var sort ='
            expect(buffer.lineForRow(1)).toBe '   function() {}'
            expect(editor.getCursorScreenPosition()).toEqual [1, 2]

      describe "when inserted text matches a decrease indent pattern", ->
        describe "when the preceding line matches an increase indent pattern", ->
          it "decreases the indentation to match that of the preceding line", ->
            editor.setCursorBufferPosition([1, Infinity])
            editor.insertText('\n')
            expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1
            editor.insertText('}')
            expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1)

        describe "when the preceding line doesn't match an increase indent pattern", ->
          it "decreases the indentation to be one level below that of the preceding line", ->
            editor.setCursorBufferPosition([3, Infinity])
            editor.insertText('\n    ')
            expect(editor.indentationForBufferRow(4)).toBe editor.indentationForBufferRow(3)
            editor.insertText('}')
            expect(editor.indentationForBufferRow(4)).toBe editor.indentationForBufferRow(3) - 1

          it "doesn't break when decreasing the indentation on a row that has no indentation", ->
            editor.setCursorBufferPosition([12, Infinity])
            editor.insertText("\n}; # too many closing brackets!")
            expect(editor.lineTextForBufferRow(13)).toBe "}; # too many closing brackets!"

      describe "when inserted text does not match a decrease indent pattern", ->
        it "does not decrease the indentation", ->
          editor.setCursorBufferPosition([12, 0])
          editor.insertText('  ')
          expect(editor.lineTextForBufferRow(12)).toBe '  };'
          editor.insertText('\t\t')
          expect(editor.lineTextForBufferRow(12)).toBe '  \t\t};'

      describe "when the current line does not match a decrease indent pattern", ->
        it "leaves the line unchanged", ->
          editor.setCursorBufferPosition([2, 4])
          expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1
          editor.insertText('foo')
          expect(editor.indentationForBufferRow(2)).toBe editor.indentationForBufferRow(1) + 1

  describe "atomic soft tabs", ->
    it "skips tab-length runs of leading whitespace when moving the cursor", ->
      editor.update({tabLength: 4, atomicSoftTabs: true})

      editor.setCursorScreenPosition([2, 3])
      expect(editor.getCursorScreenPosition()).toEqual [2, 4]

      editor.update({atomicSoftTabs: false})
      editor.setCursorScreenPosition([2, 3])
      expect(editor.getCursorScreenPosition()).toEqual [2, 3]

      editor.update({atomicSoftTabs: true})
      editor.setCursorScreenPosition([2, 3])
      expect(editor.getCursorScreenPosition()).toEqual [2, 4]

  describe ".destroy()", ->
    it "destroys marker layers associated with the text editor", ->
      selectionsMarkerLayerId = editor.selectionsMarkerLayer.id
      foldsMarkerLayerId = editor.displayLayer.foldsMarkerLayer.id
      editor.destroy()
      expect(buffer.getMarkerLayer(selectionsMarkerLayerId)).toBeUndefined()
      expect(buffer.getMarkerLayer(foldsMarkerLayerId)).toBeUndefined()

    it "notifies ::onDidDestroy observers when the editor is destroyed", ->
      destroyObserverCalled = false
      editor.onDidDestroy -> destroyObserverCalled = true

      editor.destroy()
      expect(destroyObserverCalled).toBe true

  describe ".joinLines()", ->
    describe "when no text is selected", ->
      describe "when the line below isn't empty", ->
        it "joins the line below with the current line separated by a space and moves the cursor to the start of line that was moved up", ->
          editor.setCursorBufferPosition([0, Infinity])
          editor.insertText('  ')
          editor.setCursorBufferPosition([0])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () { var sort = function(items) {'
          expect(editor.getCursorBufferPosition()).toEqual [0, 29]

      describe "when the line below is empty", ->
        it "deletes the line below and moves the cursor to the end of the line", ->
          editor.setCursorBufferPosition([9])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(9)).toBe '  };'
          expect(editor.lineTextForBufferRow(10)).toBe '  return sort(Array.apply(this, arguments));'
          expect(editor.getCursorBufferPosition()).toEqual [9, 4]

      describe "when the cursor is on the last row", ->
        it "does nothing", ->
          editor.setCursorBufferPosition([Infinity, Infinity])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(12)).toBe '};'

      describe "when the line is empty", ->
        it "joins the line below with the current line with no added space", ->
          editor.setCursorBufferPosition([10])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(10)).toBe 'return sort(Array.apply(this, arguments));'
          expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    describe "when text is selected", ->
      describe "when the selection does not span multiple lines", ->
        it "joins the line below with the current line separated by a space and retains the selected text", ->
          editor.setSelectedBufferRange([[0, 1], [0, 3]])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(0)).toBe 'var quicksort = function () { var sort = function(items) {'
          expect(editor.getSelectedBufferRange()).toEqual [[0, 1], [0, 3]]

      describe "when the selection spans multiple lines", ->
        it "joins all selected lines separated by a space and retains the selected text", ->
          editor.setSelectedBufferRange([[9, 3], [12, 1]])
          editor.joinLines()
          expect(editor.lineTextForBufferRow(9)).toBe '  }; return sort(Array.apply(this, arguments)); };'
          expect(editor.getSelectedBufferRange()).toEqual [[9, 3], [9, 49]]

  describe ".duplicateLines()", ->
    it "for each selection, duplicates all buffer lines intersected by the selection", ->
      editor.foldBufferRow(4)
      editor.setCursorBufferPosition([2, 5])
      editor.addSelectionForBufferRange([[3, 0], [8, 0]], preserveFolds: true)

      editor.duplicateLines()

      expect(editor.getTextInBufferRange([[2, 0], [13, 5]])).toBe  """
        \    if (items.length <= 1) return items;
            if (items.length <= 1) return items;
            var pivot = items.shift(), current, left = [], right = [];
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
            var pivot = items.shift(), current, left = [], right = [];
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
      """
      expect(editor.getSelectedBufferRanges()).toEqual [[[3, 5], [3, 5]], [[9, 0], [14, 0]]]

      # folds are also duplicated
      expect(editor.isFoldedAtScreenRow(5)).toBe(true)
      expect(editor.isFoldedAtScreenRow(7)).toBe(true)
      expect(editor.lineTextForScreenRow(7)).toBe "    while(items.length > 0) {" + editor.displayLayer.foldCharacter
      expect(editor.lineTextForScreenRow(8)).toBe "    return sort(left).concat(pivot).concat(sort(right));"

    it "duplicates all folded lines for empty selections on folded lines", ->
      editor.foldBufferRow(4)
      editor.setCursorBufferPosition([4, 0])

      editor.duplicateLines()

      expect(editor.getTextInBufferRange([[2, 0], [11, 5]])).toBe  """
        \    if (items.length <= 1) return items;
            var pivot = items.shift(), current, left = [], right = [];
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
            while(items.length > 0) {
              current = items.shift();
              current < pivot ? left.push(current) : right.push(current);
            }
      """
      expect(editor.getSelectedBufferRange()).toEqual [[8, 0], [8, 0]]

    it "can duplicate the last line of the buffer", ->
      editor.setSelectedBufferRange([[11, 0], [12, 2]])
      editor.duplicateLines()
      expect(editor.getTextInBufferRange([[11, 0], [14, 2]])).toBe """
        \  return sort(Array.apply(this, arguments));
        };
          return sort(Array.apply(this, arguments));
        };
      """
      expect(editor.getSelectedBufferRange()).toEqual [[13, 0], [14, 2]]

  describe ".shouldPromptToSave()", ->
    it "returns true when buffer changed", ->
      jasmine.unspy(editor, 'shouldPromptToSave')
      expect(editor.shouldPromptToSave()).toBeFalsy()
      buffer.setText('changed')
      expect(editor.shouldPromptToSave()).toBeTruthy()

    it "returns false when an edit session's buffer is in use by more than one session", ->
      jasmine.unspy(editor, 'shouldPromptToSave')
      buffer.setText('changed')

      editor2 = null
      waitsForPromise ->
        atom.workspace.getActivePane().splitRight()
        atom.workspace.open('sample.js', autoIndent: false).then (o) -> editor2 = o

      runs ->
        expect(editor.shouldPromptToSave()).toBeFalsy()
        editor2.destroy()
        expect(editor.shouldPromptToSave()).toBeTruthy()

    it "returns false when close of a window requested and edit session opened inside project", ->
      jasmine.unspy(editor, 'shouldPromptToSave')
      buffer.setText('changed')
      expect(editor.shouldPromptToSave(windowCloseRequested: true, projectHasPaths: true)).toBeFalsy()

    it "returns true when close of a window requested and edit session opened without project", ->
      jasmine.unspy(editor, 'shouldPromptToSave')
      buffer.setText('changed')
      expect(editor.shouldPromptToSave(windowCloseRequested: true, projectHasPaths: false)).toBeTruthy()

  describe "when the editor contains surrogate pair characters", ->
    it "correctly backspaces over them", ->
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97')
      editor.moveToBottom()
      editor.backspace()
      expect(editor.getText()).toBe '\uD835\uDF97\uD835\uDF97'
      editor.backspace()
      expect(editor.getText()).toBe '\uD835\uDF97'
      editor.backspace()
      expect(editor.getText()).toBe ''

    it "correctly deletes over them", ->
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97')
      editor.moveToTop()
      editor.delete()
      expect(editor.getText()).toBe '\uD835\uDF97\uD835\uDF97'
      editor.delete()
      expect(editor.getText()).toBe '\uD835\uDF97'
      editor.delete()
      expect(editor.getText()).toBe ''

    it "correctly moves over them", ->
      editor.setText('\uD835\uDF97\uD835\uDF97\uD835\uDF97\n')
      editor.moveToTop()
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [1, 0]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe "when the editor contains variation sequence character pairs", ->
    it "correctly backspaces over them", ->
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E')
      editor.moveToBottom()
      editor.backspace()
      expect(editor.getText()).toBe '\u2714\uFE0E\u2714\uFE0E'
      editor.backspace()
      expect(editor.getText()).toBe '\u2714\uFE0E'
      editor.backspace()
      expect(editor.getText()).toBe ''

    it "correctly deletes over them", ->
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E')
      editor.moveToTop()
      editor.delete()
      expect(editor.getText()).toBe '\u2714\uFE0E\u2714\uFE0E'
      editor.delete()
      expect(editor.getText()).toBe '\u2714\uFE0E'
      editor.delete()
      expect(editor.getText()).toBe ''

    it "correctly moves over them", ->
      editor.setText('\u2714\uFE0E\u2714\uFE0E\u2714\uFE0E\n')
      editor.moveToTop()
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveRight()
      expect(editor.getCursorBufferPosition()).toEqual [1, 0]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 6]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 4]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 2]
      editor.moveLeft()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe ".setIndentationForBufferRow", ->
    describe "when the editor uses soft tabs but the row has hard tabs", ->
      it "only replaces whitespace characters", ->
        editor.setSoftWrapped(true)
        editor.setText("\t1\n\t2")
        editor.setCursorBufferPosition([0, 0])
        editor.setIndentationForBufferRow(0, 2)
        expect(editor.getText()).toBe("    1\n\t2")

    describe "when the indentation level is a non-integer", ->
      it "does not throw an exception", ->
        editor.setSoftWrapped(true)
        editor.setText("\t1\n\t2")
        editor.setCursorBufferPosition([0, 0])
        editor.setIndentationForBufferRow(0, 2.1)
        expect(editor.getText()).toBe("    1\n\t2")

  describe "when the editor's grammar has an injection selector", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-text')

      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

    it "includes the grammar's patterns when the selector matches the current scope in other grammars", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-hyperlink')

      runs ->
        grammar = atom.grammars.selectGrammar("text.js")
        {line, tags} = grammar.tokenizeLine("var i; // http://github.com")

        tokens = atom.grammars.decodeTokens(line, tags)
        expect(tokens[0].value).toBe "var"
        expect(tokens[0].scopes).toEqual ["source.js", "storage.type.var.js"]

        expect(tokens[6].value).toBe "http://github.com"
        expect(tokens[6].scopes).toEqual ["source.js", "comment.line.double-slash.js", "markup.underline.link.http.hyperlink"]

    describe "when the grammar is added", ->
      it "retokenizes existing buffers that contain tokens that match the injection selector", ->
        waitsForPromise ->
          atom.workspace.open('sample.js').then (o) -> editor = o

        runs ->
          editor.setText("// http://github.com")

          tokens = editor.tokensForScreenRow(0)
          expect(tokens).toEqual [
            {text: '//', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--punctuation.syntax--definition.syntax--comment.syntax--js']},
            {text: ' http://github.com', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']}
          ]

        waitsForPromise ->
          atom.packages.activatePackage('language-hyperlink')

        runs ->
          tokens = editor.tokensForScreenRow(0)
          expect(tokens).toEqual [
            {text: '//', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--punctuation.syntax--definition.syntax--comment.syntax--js']},
            {text: ' ', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']}
            {text: 'http://github.com', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--markup.syntax--underline.syntax--link.syntax--http.syntax--hyperlink']}
          ]

      describe "when the grammar is updated", ->
        it "retokenizes existing buffers that contain tokens that match the injection selector", ->
          waitsForPromise ->
            atom.workspace.open('sample.js').then (o) -> editor = o

          runs ->
            editor.setText("// SELECT * FROM OCTOCATS")

            tokens = editor.tokensForScreenRow(0)
            expect(tokens).toEqual [
              {text: '//', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--punctuation.syntax--definition.syntax--comment.syntax--js']},
              {text: ' SELECT * FROM OCTOCATS', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']}
            ]

          waitsForPromise ->
            atom.packages.activatePackage('package-with-injection-selector')

          runs ->
            tokens = editor.tokensForScreenRow(0)
            expect(tokens).toEqual [
              {text: '//', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--punctuation.syntax--definition.syntax--comment.syntax--js']},
              {text: ' SELECT * FROM OCTOCATS', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']}
            ]

          waitsForPromise ->
            atom.packages.activatePackage('language-sql')

          runs ->
            tokens = editor.tokensForScreenRow(0)
            expect(tokens).toEqual [
              {text: '//', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--punctuation.syntax--definition.syntax--comment.syntax--js']},
              {text: ' ', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']},
              {text: 'SELECT', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--keyword.syntax--other.syntax--DML.syntax--sql']},
              {text: ' ', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']},
              {text: '*', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--keyword.syntax--operator.syntax--star.syntax--sql']},
              {text: ' ', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']},
              {text: 'FROM', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js', 'syntax--keyword.syntax--other.syntax--DML.syntax--sql']},
              {text: ' OCTOCATS', scopes: ['syntax--source.syntax--js', 'syntax--comment.syntax--line.syntax--double-slash.syntax--js']}
            ]

  describe ".normalizeTabsInBufferRange()", ->
    it "normalizes tabs depending on the editor's soft tab/tab length settings", ->
      editor.setTabLength(1)
      editor.setSoftTabs(true)
      editor.setText('\t\t\t')
      editor.normalizeTabsInBufferRange([[0, 0], [0, 1]])
      expect(editor.getText()).toBe ' \t\t'

      editor.setTabLength(2)
      editor.normalizeTabsInBufferRange([[0, 0], [Infinity, Infinity]])
      expect(editor.getText()).toBe '     '

      editor.setSoftTabs(false)
      editor.normalizeTabsInBufferRange([[0, 0], [Infinity, Infinity]])
      expect(editor.getText()).toBe '     '

  describe ".pageUp/Down()", ->
    it "moves the cursor down one page length", ->
      editor.setRowsPerPage(5)

      expect(editor.getCursorBufferPosition().row).toBe 0

      editor.pageDown()
      expect(editor.getCursorBufferPosition().row).toBe 5

      editor.pageDown()
      expect(editor.getCursorBufferPosition().row).toBe 10

      editor.pageUp()
      expect(editor.getCursorBufferPosition().row).toBe 5

      editor.pageUp()
      expect(editor.getCursorBufferPosition().row).toBe 0

  describe ".selectPageUp/Down()", ->
    it "selects one screen height of text up or down", ->
      editor.setRowsPerPage(5)

      expect(editor.getCursorBufferPosition().row).toBe 0

      editor.selectPageDown()
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [5, 0]]]

      editor.selectPageDown()
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [10, 0]]]

      editor.selectPageDown()
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [12, 2]]]

      editor.moveToBottom()
      editor.selectPageUp()
      expect(editor.getSelectedBufferRanges()).toEqual [[[7, 0], [12, 2]]]

      editor.selectPageUp()
      expect(editor.getSelectedBufferRanges()).toEqual [[[2, 0], [12, 2]]]

      editor.selectPageUp()
      expect(editor.getSelectedBufferRanges()).toEqual [[[0, 0], [12, 2]]]

  describe "::setFirstVisibleScreenRow() and ::getFirstVisibleScreenRow()", ->
    beforeEach ->
      line = Array(9).join('0123456789')
      editor.setText([1..100].map(-> line).join('\n'))
      expect(editor.getLineCount()).toBe 100
      expect(editor.lineTextForBufferRow(0).length).toBe 80

    describe "when the editor doesn't have a height and lineHeightInPixels", ->
      it "does not affect the editor's visible row range", ->
        expect(editor.getVisibleRowRange()).toBeNull()

        editor.setFirstVisibleScreenRow(1)
        expect(editor.getFirstVisibleScreenRow()).toEqual 1

        editor.setFirstVisibleScreenRow(3)
        expect(editor.getFirstVisibleScreenRow()).toEqual 3

        expect(editor.getVisibleRowRange()).toBeNull()
        expect(editor.getLastVisibleScreenRow()).toBeNull()

    describe "when the editor has a height and lineHeightInPixels", ->
      beforeEach ->
        editor.update({scrollPastEnd: true})
        editor.setHeight(100, true)
        editor.setLineHeightInPixels(10)

      it "updates the editor's visible row range", ->
        editor.setFirstVisibleScreenRow(2)
        expect(editor.getFirstVisibleScreenRow()).toEqual 2
        expect(editor.getLastVisibleScreenRow()).toBe 12
        expect(editor.getVisibleRowRange()).toEqual [2, 12]

      it "notifies ::onDidChangeFirstVisibleScreenRow observers", ->
        changeCount = 0
        editor.onDidChangeFirstVisibleScreenRow -> changeCount++

        editor.setFirstVisibleScreenRow(2)
        expect(changeCount).toBe 1

        editor.setFirstVisibleScreenRow(2)
        expect(changeCount).toBe 1

        editor.setFirstVisibleScreenRow(3)
        expect(changeCount).toBe 2

      it "ensures that the top row is less than the buffer's line count", ->
        editor.setFirstVisibleScreenRow(102)
        expect(editor.getFirstVisibleScreenRow()).toEqual 99
        expect(editor.getVisibleRowRange()).toEqual [99, 99]

      it "ensures that the left column is less than the length of the longest screen line", ->
        editor.setFirstVisibleScreenRow(10)
        expect(editor.getFirstVisibleScreenRow()).toEqual 10

        editor.setText("\n\n\n")

        editor.setFirstVisibleScreenRow(10)
        expect(editor.getFirstVisibleScreenRow()).toEqual 3

      describe "when the 'editor.scrollPastEnd' option is set to false", ->
        it "ensures that the bottom row is less than the buffer's line count", ->
          editor.update({scrollPastEnd: false})
          editor.setFirstVisibleScreenRow(95)
          expect(editor.getFirstVisibleScreenRow()).toEqual 89
          expect(editor.getVisibleRowRange()).toEqual [89, 99]

  describe "::scrollToScreenPosition(position, [options])", ->
    it "triggers ::onDidRequestAutoscroll with the logical coordinates along with the options", ->
      scrollSpy = jasmine.createSpy("::onDidRequestAutoscroll")
      editor.onDidRequestAutoscroll(scrollSpy)

      editor.scrollToScreenPosition([8, 20])
      editor.scrollToScreenPosition([8, 20], center: true)
      editor.scrollToScreenPosition([8, 20], center: false, reversed: true)

      expect(scrollSpy).toHaveBeenCalledWith(screenRange: [[8, 20], [8, 20]], options: {})
      expect(scrollSpy).toHaveBeenCalledWith(screenRange: [[8, 20], [8, 20]], options: {center: true})
      expect(scrollSpy).toHaveBeenCalledWith(screenRange: [[8, 20], [8, 20]], options: {center: false, reversed: true})

  describe "scroll past end", ->
    it "returns false by default but can be customized", ->
      expect(editor.getScrollPastEnd()).toBe(false)
      editor.update({scrollPastEnd: true})
      expect(editor.getScrollPastEnd()).toBe(true)
      editor.update({scrollPastEnd: false})
      expect(editor.getScrollPastEnd()).toBe(false)

  describe "auto height", ->
    it "returns true by default but can be customized", ->
      editor = new TextEditor
      expect(editor.getAutoHeight()).toBe(true)
      editor.update({autoHeight: false})
      expect(editor.getAutoHeight()).toBe(false)
      editor.update({autoHeight: true})
      expect(editor.getAutoHeight()).toBe(true)
      editor.destroy()

  describe "auto width", ->
    it "returns false by default but can be customized", ->
      expect(editor.getAutoWidth()).toBe(false)
      editor.update({autoWidth: true})
      expect(editor.getAutoWidth()).toBe(true)
      editor.update({autoWidth: false})
      expect(editor.getAutoWidth()).toBe(false)

  describe '.get/setPlaceholderText()', ->
    it 'can be created with placeholderText', ->
      newEditor = new TextEditor({
        mini: true
        placeholderText: 'yep'
      })
      expect(newEditor.getPlaceholderText()).toBe 'yep'

    it 'models placeholderText and emits an event when changed', ->
      editor.onDidChangePlaceholderText handler = jasmine.createSpy()

      expect(editor.getPlaceholderText()).toBeUndefined()

      editor.setPlaceholderText('OK')
      expect(handler).toHaveBeenCalledWith 'OK'
      expect(editor.getPlaceholderText()).toBe 'OK'

  describe 'gutters', ->
    describe 'the TextEditor constructor', ->
      it 'creates a line-number gutter', ->
        expect(editor.getGutters().length).toBe 1
        lineNumberGutter = editor.gutterWithName('line-number')
        expect(lineNumberGutter.name).toBe 'line-number'
        expect(lineNumberGutter.priority).toBe 0

    describe '::addGutter', ->
      it 'can add a gutter', ->
        expect(editor.getGutters().length).toBe 1 # line-number gutter
        options =
          name: 'test-gutter'
          priority: 1
        gutter = editor.addGutter options
        expect(editor.getGutters().length).toBe 2
        expect(editor.getGutters()[1]).toBe gutter

      it "does not allow a custom gutter with the 'line-number' name.", ->
        expect(editor.addGutter.bind(editor, {name: 'line-number'})).toThrow()

    describe '::decorateMarker', ->
      [marker] = []

      beforeEach ->
        marker = editor.markBufferRange([[1, 0], [1, 0]])

      it 'reflects an added decoration when one of its custom gutters is decorated.', ->
        gutter = editor.addGutter {'name': 'custom-gutter'}
        decoration = gutter.decorateMarker marker, {class: 'custom-class'}
        gutterDecorations = editor.getDecorations
          type: 'gutter'
          gutterName: 'custom-gutter'
          class: 'custom-class'
        expect(gutterDecorations.length).toBe 1
        expect(gutterDecorations[0]).toBe decoration

      it 'reflects an added decoration when its line-number gutter is decorated.', ->
        decoration = editor.gutterWithName('line-number').decorateMarker marker, {class: 'test-class'}
        gutterDecorations = editor.getDecorations
          type: 'line-number'
          gutterName: 'line-number'
          class: 'test-class'
        expect(gutterDecorations.length).toBe 1
        expect(gutterDecorations[0]).toBe decoration

    describe '::observeGutters', ->
      [payloads, callback] = []

      beforeEach ->
        payloads = []
        callback = (payload) ->
          payloads.push(payload)

      it 'calls the callback immediately with each existing gutter, and with each added gutter after that.', ->
        lineNumberGutter = editor.gutterWithName('line-number')
        editor.observeGutters(callback)
        expect(payloads).toEqual [lineNumberGutter]
        gutter1 = editor.addGutter({name: 'test-gutter-1'})
        expect(payloads).toEqual [lineNumberGutter, gutter1]
        gutter2 = editor.addGutter({name: 'test-gutter-2'})
        expect(payloads).toEqual [lineNumberGutter, gutter1, gutter2]

      it 'does not call the callback when a gutter is removed.', ->
        gutter = editor.addGutter({name: 'test-gutter'})
        editor.observeGutters(callback)
        payloads = []
        gutter.destroy()
        expect(payloads).toEqual []

      it 'does not call the callback after the subscription has been disposed.', ->
        subscription = editor.observeGutters(callback)
        payloads = []
        subscription.dispose()
        editor.addGutter({name: 'test-gutter'})
        expect(payloads).toEqual []

    describe '::onDidAddGutter', ->
      [payloads, callback] = []

      beforeEach ->
        payloads = []
        callback = (payload) ->
          payloads.push(payload)

      it 'calls the callback with each newly-added gutter, but not with existing gutters.', ->
        editor.onDidAddGutter(callback)
        expect(payloads).toEqual []
        gutter = editor.addGutter({name: 'test-gutter'})
        expect(payloads).toEqual [gutter]

      it 'does not call the callback after the subscription has been disposed.', ->
        subscription = editor.onDidAddGutter(callback)
        payloads = []
        subscription.dispose()
        editor.addGutter({name: 'test-gutter'})
        expect(payloads).toEqual []

    describe '::onDidRemoveGutter', ->
      [payloads, callback] = []

      beforeEach ->
        payloads = []
        callback = (payload) ->
          payloads.push(payload)

      it 'calls the callback when a gutter is removed.', ->
        gutter = editor.addGutter({name: 'test-gutter'})
        editor.onDidRemoveGutter(callback)
        expect(payloads).toEqual []
        gutter.destroy()
        expect(payloads).toEqual ['test-gutter']

      it 'does not call the callback after the subscription has been disposed.', ->
        gutter = editor.addGutter({name: 'test-gutter'})
        subscription = editor.onDidRemoveGutter(callback)
        subscription.dispose()
        gutter.destroy()
        expect(payloads).toEqual []

  describe "decorations", ->
    describe "::decorateMarker", ->
      it "includes the decoration in the object returned from ::decorationsStateForScreenRowRange", ->
        marker = editor.markBufferRange([[2, 4], [6, 8]])
        decoration = editor.decorateMarker(marker, type: 'highlight', class: 'foo')
        expect(editor.decorationsStateForScreenRowRange(0, 5)[decoration.id]).toEqual {
          properties: {type: 'highlight', class: 'foo'}
          screenRange: marker.getScreenRange(),
          bufferRange: marker.getBufferRange(),
          rangeIsReversed: false
        }

      it "does not throw errors after the marker's containing layer is destroyed", ->
        layer = editor.addMarkerLayer()
        marker = layer.markBufferRange([[2, 4], [6, 8]])
        decoration = editor.decorateMarker(marker, type: 'highlight', class: 'foo')
        layer.destroy()
        editor.decorationsStateForScreenRowRange(0, 5)

    describe "::decorateMarkerLayer", ->
      it "based on the markers in the layer, includes multiple decoration objects with the same properties and different ranges in the object returned from ::decorationsStateForScreenRowRange", ->
        layer1 = editor.getBuffer().addMarkerLayer()
        marker1 = layer1.markRange([[2, 4], [6, 8]])
        marker2 = layer1.markRange([[11, 0], [11, 12]])
        layer2 = editor.getBuffer().addMarkerLayer()
        marker3 = layer2.markRange([[8, 0], [9, 0]])

        layer1Decoration1 = editor.decorateMarkerLayer(layer1, type: 'highlight', class: 'foo')
        layer1Decoration2 = editor.decorateMarkerLayer(layer1, type: 'highlight', class: 'bar')
        layer2Decoration = editor.decorateMarkerLayer(layer2, type: 'highlight', class: 'baz')

        decorationState = editor.decorationsStateForScreenRowRange(0, 13)

        expect(decorationState["#{layer1Decoration1.id}-#{marker1.id}"]).toEqual {
          properties: {type: 'highlight', class: 'foo'},
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        }
        expect(decorationState["#{layer1Decoration1.id}-#{marker2.id}"]).toEqual {
          properties: {type: 'highlight', class: 'foo'},
          screenRange: marker2.getRange(),
          bufferRange: marker2.getRange(),
          rangeIsReversed: false
        }
        expect(decorationState["#{layer1Decoration2.id}-#{marker1.id}"]).toEqual {
          properties: {type: 'highlight', class: 'bar'},
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        }
        expect(decorationState["#{layer1Decoration2.id}-#{marker2.id}"]).toEqual {
          properties: {type: 'highlight', class: 'bar'},
          screenRange: marker2.getRange(),
          bufferRange: marker2.getRange(),
          rangeIsReversed: false
        }
        expect(decorationState["#{layer2Decoration.id}-#{marker3.id}"]).toEqual {
          properties: {type: 'highlight', class: 'baz'},
          screenRange: marker3.getRange(),
          bufferRange: marker3.getRange(),
          rangeIsReversed: false
        }

        layer1Decoration1.destroy()

        decorationState = editor.decorationsStateForScreenRowRange(0, 12)
        expect(decorationState["#{layer1Decoration1.id}-#{marker1.id}"]).toBeUndefined()
        expect(decorationState["#{layer1Decoration1.id}-#{marker2.id}"]).toBeUndefined()
        expect(decorationState["#{layer1Decoration2.id}-#{marker1.id}"]).toEqual {
          properties: {type: 'highlight', class: 'bar'},
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        }
        expect(decorationState["#{layer1Decoration2.id}-#{marker2.id}"]).toEqual {
          properties: {type: 'highlight', class: 'bar'},
          screenRange: marker2.getRange(),
          bufferRange: marker2.getRange(),
          rangeIsReversed: false
        }
        expect(decorationState["#{layer2Decoration.id}-#{marker3.id}"]).toEqual {
          properties: {type: 'highlight', class: 'baz'},
          screenRange: marker3.getRange(),
          bufferRange: marker3.getRange(),
          rangeIsReversed: false
        }

        layer1Decoration2.setPropertiesForMarker(marker1, {type: 'highlight', class: 'quux'})
        decorationState = editor.decorationsStateForScreenRowRange(0, 12)
        expect(decorationState["#{layer1Decoration2.id}-#{marker1.id}"]).toEqual {
          properties: {type: 'highlight', class: 'quux'},
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        }

        layer1Decoration2.setPropertiesForMarker(marker1, null)
        decorationState = editor.decorationsStateForScreenRowRange(0, 12)
        expect(decorationState["#{layer1Decoration2.id}-#{marker1.id}"]).toEqual {
          properties: {type: 'highlight', class: 'bar'},
          screenRange: marker1.getRange(),
          bufferRange: marker1.getRange(),
          rangeIsReversed: false
        }

  describe "invisibles", ->
    beforeEach ->
      editor.update({showInvisibles: true})

    it "substitutes invisible characters according to the given rules", ->
      previousLineText = editor.lineTextForScreenRow(0)
      editor.update({invisibles: {eol: '?'}})
      expect(editor.lineTextForScreenRow(0)).not.toBe(previousLineText)
      expect(editor.lineTextForScreenRow(0).endsWith('?')).toBe(true)
      expect(editor.getInvisibles()).toEqual(eol: '?')

    it "does not use invisibles if showInvisibles is set to false", ->
      editor.update({invisibles: {eol: '?'}})
      expect(editor.lineTextForScreenRow(0).endsWith('?')).toBe(true)

      editor.update({showInvisibles: false})
      expect(editor.lineTextForScreenRow(0).endsWith('?')).toBe(false)

  describe "indent guides", ->
    it "shows indent guides when `editor.showIndentGuide` is set to true and the editor is not mini", ->
      editor.setText("  foo")
      editor.setTabLength(2)

      editor.update({showIndentGuide: false})
      expect(editor.tokensForScreenRow(0)).toEqual [
        {text: '  ', scopes: ['syntax--source.syntax--js', 'leading-whitespace']},
        {text: 'foo', scopes: ['syntax--source.syntax--js']}
      ]

      editor.update({showIndentGuide: true})
      expect(editor.tokensForScreenRow(0)).toEqual [
        {text: '  ', scopes: ['syntax--source.syntax--js', 'leading-whitespace indent-guide']},
        {text: 'foo', scopes: ['syntax--source.syntax--js']}
      ]

      editor.setMini(true)
      expect(editor.tokensForScreenRow(0)).toEqual [
        {text: '  ', scopes: ['syntax--source.syntax--js', 'leading-whitespace']},
        {text: 'foo', scopes: ['syntax--source.syntax--js']}
      ]

  describe "when the editor is constructed with the grammar option set", ->
    beforeEach ->
      waitsForPromise ->
        atom.packages.activatePackage('language-coffee-script')

    it "sets the grammar", ->
      editor = new TextEditor({grammar: atom.grammars.grammarForScopeName('source.coffee')})
      expect(editor.getGrammar().name).toBe 'CoffeeScript'

  describe "softWrapAtPreferredLineLength", ->
    it "soft wraps the editor at the preferred line length unless the editor is narrower", ->
      editor.update({
        editorWidthInChars: 30
        softWrapped: true
        softWrapAtPreferredLineLength: true
        preferredLineLength: 20
      })

      expect(editor.lineTextForScreenRow(0)).toBe 'var quicksort = '

      editor.update({editorWidthInChars: 10})
      expect(editor.lineTextForScreenRow(0)).toBe 'var '

  describe "softWrapHangingIndentLength", ->
    it "controls how much extra indentation is applied to soft-wrapped lines", ->
      editor.setText('123456789')
      editor.update({
        editorWidthInChars: 8
        softWrapped: true
        softWrapHangingIndentLength: 2
      })
      expect(editor.lineTextForScreenRow(1)).toEqual '  9'

      editor.update({softWrapHangingIndentLength: 4})
      expect(editor.lineTextForScreenRow(1)).toEqual '    9'

  describe "::getElement", ->
    it "returns an element", ->
      expect(editor.getElement() instanceof HTMLElement).toBe(true)
