describe "TextEditor cursor", ->
  [buffer, editor, lineLengths] = []

  beforeEach ->
    waitsForPromise ->
      atom.workspace.open('sample.js', {autoIndent: false}).then (o) -> editor = o

    runs ->
      buffer = editor.buffer
      editor.update({autoIndent: false})
      lineLengths = buffer.getLines().map (line) -> line.length

  afterEach ->
    editor.destroy()

  describe ".getLastCursor()", ->
    it "returns the most recently created cursor", ->
      editor.addCursorAtScreenPosition([1, 0])
      lastCursor = editor.addCursorAtScreenPosition([2, 0])
      expect(editor.getLastCursor()).toBe lastCursor

    it "creates a new cursor at (0, 0) if the last cursor has been destroyed", ->
      editor.getLastCursor().destroy()
      expect(editor.getLastCursor().getBufferPosition()).toEqual([0, 0])

  describe ".getCursors()", ->
    it "creates a new cursor at (0, 0) if the last cursor has been destroyed", ->
      editor.getLastCursor().destroy()
      expect(editor.getCursors()[0].getBufferPosition()).toEqual([0, 0])

  describe "when the cursor moves", ->
    it "clears a goal column established by vertical movement", ->
      editor.setText('b')
      editor.setCursorBufferPosition([0, 0])
      editor.insertNewline()
      editor.moveUp()
      editor.insertText('a')
      editor.moveDown()
      expect(editor.getCursorBufferPosition()).toEqual [1, 1]

    it "emits an event with the old position, new position, and the cursor that moved", ->
      cursorCallback = jasmine.createSpy('cursor-changed-position')
      editorCallback = jasmine.createSpy('editor-changed-cursor-position')

      editor.getLastCursor().onDidChangePosition(cursorCallback)
      editor.onDidChangeCursorPosition(editorCallback)

      editor.setCursorBufferPosition([2, 4])

      expect(editorCallback).toHaveBeenCalled()
      expect(cursorCallback).toHaveBeenCalled()
      eventObject = editorCallback.mostRecentCall.args[0]
      expect(cursorCallback.mostRecentCall.args[0]).toEqual(eventObject)

      expect(eventObject.oldBufferPosition).toEqual [0, 0]
      expect(eventObject.oldScreenPosition).toEqual [0, 0]
      expect(eventObject.newBufferPosition).toEqual [2, 4]
      expect(eventObject.newScreenPosition).toEqual [2, 4]
      expect(eventObject.cursor).toBe editor.getLastCursor()

  describe ".setCursorScreenPosition(screenPosition)", ->
    it "clears a goal column established by vertical movement", ->
      # set a goal column by moving down
      editor.setCursorScreenPosition(row: 3, column: lineLengths[3])
      editor.moveDown()
      expect(editor.getCursorScreenPosition().column).not.toBe 6

      # clear the goal column by explicitly setting the cursor position
      editor.setCursorScreenPosition([4, 6])
      expect(editor.getCursorScreenPosition().column).toBe 6

      editor.moveDown()
      expect(editor.getCursorScreenPosition().column).toBe 6

    it "merges multiple cursors", ->
      editor.setCursorScreenPosition([0, 0])
      editor.addCursorAtScreenPosition([0, 1])
      [cursor1, cursor2] = editor.getCursors()
      editor.setCursorScreenPosition([4, 7])
      expect(editor.getCursors().length).toBe 1
      expect(editor.getCursors()).toEqual [cursor1]
      expect(editor.getCursorScreenPosition()).toEqual [4, 7]

    describe "when soft-wrap is enabled and code is folded", ->
      beforeEach ->
        editor.setSoftWrapped(true)
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(50)
        editor.foldBufferRowRange(2, 3)

      it "positions the cursor at the buffer position that corresponds to the given screen position", ->
        editor.setCursorScreenPosition([9, 0])
        expect(editor.getCursorBufferPosition()).toEqual [8, 10]

  describe ".moveUp()", ->
    it "moves the cursor up", ->
      editor.setCursorScreenPosition([2, 2])
      editor.moveUp()
      expect(editor.getCursorScreenPosition()).toEqual [1, 2]

    it "retains the goal column across lines of differing length", ->
      expect(lineLengths[6]).toBeGreaterThan(32)
      editor.setCursorScreenPosition(row: 6, column: 32)

      editor.moveUp()
      expect(editor.getCursorScreenPosition().column).toBe lineLengths[5]

      editor.moveUp()
      expect(editor.getCursorScreenPosition().column).toBe lineLengths[4]

      editor.moveUp()
      expect(editor.getCursorScreenPosition().column).toBe 32

    describe "when the cursor is on the first line", ->
      it "moves the cursor to the beginning of the line, but retains the goal column", ->
        editor.setCursorScreenPosition([0, 4])
        editor.moveUp()
        expect(editor.getCursorScreenPosition()).toEqual([0, 0])

        editor.moveDown()
        expect(editor.getCursorScreenPosition()).toEqual([1, 4])

    describe "when there is a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange([[4, 9], [5, 10]])

      it "moves above the selection", ->
        cursor = editor.getLastCursor()
        editor.moveUp()
        expect(cursor.getBufferPosition()).toEqual [3, 9]

    it "merges cursors when they overlap", ->
      editor.addCursorAtScreenPosition([1, 0])
      [cursor1, cursor2] = editor.getCursors()

      editor.moveUp()
      expect(editor.getCursors()).toEqual [cursor1]
      expect(cursor1.getBufferPosition()).toEqual [0, 0]

    describe "when the cursor was moved down from the beginning of an indented soft-wrapped line", ->
      it "moves to the beginning of the previous line", ->
        editor.setSoftWrapped(true)
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(50)

        editor.setCursorScreenPosition([3, 0])
        editor.moveDown()
        editor.moveDown()
        editor.moveUp()
        expect(editor.getCursorScreenPosition()).toEqual [4, 4]

  describe ".moveDown()", ->
    it "moves the cursor down", ->
      editor.setCursorScreenPosition([2, 2])
      editor.moveDown()
      expect(editor.getCursorScreenPosition()).toEqual [3, 2]

    it "retains the goal column across lines of differing length", ->
      editor.setCursorScreenPosition(row: 3, column: lineLengths[3])

      editor.moveDown()
      expect(editor.getCursorScreenPosition().column).toBe lineLengths[4]

      editor.moveDown()
      expect(editor.getCursorScreenPosition().column).toBe lineLengths[5]

      editor.moveDown()
      expect(editor.getCursorScreenPosition().column).toBe lineLengths[3]

    describe "when the cursor is on the last line", ->
      it "moves the cursor to the end of line, but retains the goal column when moving back up", ->
        lastLineIndex = buffer.getLines().length - 1
        lastLine = buffer.lineForRow(lastLineIndex)
        expect(lastLine.length).toBeGreaterThan(0)

        editor.setCursorScreenPosition(row: lastLineIndex, column: editor.getTabLength())
        editor.moveDown()
        expect(editor.getCursorScreenPosition()).toEqual(row: lastLineIndex, column: lastLine.length)

        editor.moveUp()
        expect(editor.getCursorScreenPosition().column).toBe editor.getTabLength()

      it "retains a goal column of 0 when moving back up", ->
        lastLineIndex = buffer.getLines().length - 1
        lastLine = buffer.lineForRow(lastLineIndex)
        expect(lastLine.length).toBeGreaterThan(0)

        editor.setCursorScreenPosition(row: lastLineIndex, column: 0)
        editor.moveDown()
        editor.moveUp()
        expect(editor.getCursorScreenPosition().column).toBe 0

    describe "when the cursor is at the beginning of an indented soft-wrapped line", ->
      it "moves to the beginning of the line's continuation on the next screen row", ->
        editor.setSoftWrapped(true)
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(50)

        editor.setCursorScreenPosition([3, 0])
        editor.moveDown()
        expect(editor.getCursorScreenPosition()).toEqual [4, 4]


    describe "when there is a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange([[4, 9], [5, 10]])

      it "moves below the selection", ->
        cursor = editor.getLastCursor()
        editor.moveDown()
        expect(cursor.getBufferPosition()).toEqual [6, 10]

    it "merges cursors when they overlap", ->
      editor.setCursorScreenPosition([12, 2])
      editor.addCursorAtScreenPosition([11, 2])
      [cursor1, cursor2] = editor.getCursors()

      editor.moveDown()
      expect(editor.getCursors()).toEqual [cursor1]
      expect(cursor1.getBufferPosition()).toEqual [12, 2]

  describe ".moveLeft()", ->
    it "moves the cursor by one column to the left", ->
      editor.setCursorScreenPosition([1, 8])
      editor.moveLeft()
      expect(editor.getCursorScreenPosition()).toEqual [1, 7]

    it "moves the cursor by n columns to the left", ->
      editor.setCursorScreenPosition([1, 8])
      editor.moveLeft(4)
      expect(editor.getCursorScreenPosition()).toEqual [1, 4]

    it "moves the cursor by two rows up when the columnCount is longer than an entire line", ->
      editor.setCursorScreenPosition([2, 2])
      editor.moveLeft(34)
      expect(editor.getCursorScreenPosition()).toEqual [0, 29]

    it "moves the cursor to the beginning columnCount is longer than the position in the buffer", ->
      editor.setCursorScreenPosition([1, 0])
      editor.moveLeft(100)
      expect(editor.getCursorScreenPosition()).toEqual [0, 0]

    describe "when the cursor is in the first column", ->
      describe "when there is a previous line", ->
        it "wraps to the end of the previous line", ->
          editor.setCursorScreenPosition(row: 1, column: 0)
          editor.moveLeft()
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: buffer.lineForRow(0).length)

        it "moves the cursor by one row up and n columns to the left", ->
          editor.setCursorScreenPosition([1, 0])
          editor.moveLeft(4)
          expect(editor.getCursorScreenPosition()).toEqual [0, 26]

      describe "when the next line is empty", ->
        it "wraps to the beginning of the previous line", ->
          editor.setCursorScreenPosition([11, 0])
          editor.moveLeft()
          expect(editor.getCursorScreenPosition()).toEqual [10, 0]

      describe "when line is wrapped and follow previous line indentation", ->
        beforeEach ->
          editor.setSoftWrapped(true)
          editor.setDefaultCharWidth(1)
          editor.setEditorWidthInChars(50)

        it "wraps to the end of the previous line", ->
          editor.setCursorScreenPosition([4, 4])
          editor.moveLeft()
          expect(editor.getCursorScreenPosition()).toEqual [3, 46]

      describe "when the cursor is on the first line", ->
        it "remains in the same position (0,0)", ->
          editor.setCursorScreenPosition(row: 0, column: 0)
          editor.moveLeft()
          expect(editor.getCursorScreenPosition()).toEqual(row: 0, column: 0)

        it "remains in the same position (0,0) when columnCount is specified", ->
          editor.setCursorScreenPosition([0, 0])
          editor.moveLeft(4)
          expect(editor.getCursorScreenPosition()).toEqual [0, 0]

    describe "when softTabs is enabled and the cursor is preceded by leading whitespace", ->
      it "skips tabLength worth of whitespace at a time", ->
        editor.setCursorBufferPosition([5, 6])

        editor.moveLeft()
        expect(editor.getCursorBufferPosition()).toEqual [5, 4]

    describe "when there is a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange([[5, 22], [5, 27]])

      it "moves to the left of the selection", ->
        cursor = editor.getLastCursor()
        editor.moveLeft()
        expect(cursor.getBufferPosition()).toEqual [5, 22]

        editor.moveLeft()
        expect(cursor.getBufferPosition()).toEqual [5, 21]

    it "merges cursors when they overlap", ->
      editor.setCursorScreenPosition([0, 0])
      editor.addCursorAtScreenPosition([0, 1])

      [cursor1, cursor2] = editor.getCursors()
      editor.moveLeft()
      expect(editor.getCursors()).toEqual [cursor1]
      expect(cursor1.getBufferPosition()).toEqual [0, 0]

  describe ".moveRight()", ->
    it "moves the cursor by one column to the right", ->
      editor.setCursorScreenPosition([3, 3])
      editor.moveRight()
      expect(editor.getCursorScreenPosition()).toEqual [3, 4]

    it "moves the cursor by n columns to the right", ->
      editor.setCursorScreenPosition([3, 7])
      editor.moveRight(4)
      expect(editor.getCursorScreenPosition()).toEqual [3, 11]

    it "moves the cursor by two rows down when the columnCount is longer than an entire line", ->
      editor.setCursorScreenPosition([0, 29])
      editor.moveRight(34)
      expect(editor.getCursorScreenPosition()).toEqual [2, 2]

    it "moves the cursor to the end of the buffer when columnCount is longer than the number of characters following the cursor position", ->
      editor.setCursorScreenPosition([11, 5])
      editor.moveRight(100)
      expect(editor.getCursorScreenPosition()).toEqual [12, 2]

    describe "when the cursor is on the last column of a line", ->
      describe "when there is a subsequent line", ->
        it "wraps to the beginning of the next line", ->
          editor.setCursorScreenPosition([0, buffer.lineForRow(0).length])
          editor.moveRight()
          expect(editor.getCursorScreenPosition()).toEqual [1, 0]

        it "moves the cursor by one row down and n columns to the right", ->
          editor.setCursorScreenPosition([0, buffer.lineForRow(0).length])
          editor.moveRight(4)
          expect(editor.getCursorScreenPosition()).toEqual [1, 3]

      describe "when the next line is empty", ->
        it "wraps to the beginning of the next line", ->
          editor.setCursorScreenPosition([9, 4])
          editor.moveRight()
          expect(editor.getCursorScreenPosition()).toEqual [10, 0]

      describe "when the cursor is on the last line", ->
        it "remains in the same position", ->
          lastLineIndex = buffer.getLines().length - 1
          lastLine = buffer.lineForRow(lastLineIndex)
          expect(lastLine.length).toBeGreaterThan(0)

          lastPosition = {row: lastLineIndex, column: lastLine.length}
          editor.setCursorScreenPosition(lastPosition)
          editor.moveRight()

          expect(editor.getCursorScreenPosition()).toEqual(lastPosition)

    describe "when there is a selection", ->
      beforeEach ->
        editor.setSelectedBufferRange([[5, 22], [5, 27]])

      it "moves to the left of the selection", ->
        cursor = editor.getLastCursor()
        editor.moveRight()
        expect(cursor.getBufferPosition()).toEqual [5, 27]

        editor.moveRight()
        expect(cursor.getBufferPosition()).toEqual [5, 28]

    it "merges cursors when they overlap", ->
      editor.setCursorScreenPosition([12, 2])
      editor.addCursorAtScreenPosition([12, 1])
      [cursor1, cursor2] = editor.getCursors()

      editor.moveRight()
      expect(editor.getCursors()).toEqual [cursor1]
      expect(cursor1.getBufferPosition()).toEqual [12, 2]

  describe ".moveToTop()", ->
    it "moves the cursor to the top of the buffer", ->
      editor.setCursorScreenPosition [11, 1]
      editor.addCursorAtScreenPosition [12, 0]
      editor.moveToTop()
      expect(editor.getCursors().length).toBe 1
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe ".moveToBottom()", ->
    it "moves the cusor to the bottom of the buffer", ->
      editor.setCursorScreenPosition [0, 0]
      editor.addCursorAtScreenPosition [1, 0]
      editor.moveToBottom()
      expect(editor.getCursors().length).toBe 1
      expect(editor.getCursorBufferPosition()).toEqual [12, 2]

  describe ".moveToBeginningOfScreenLine()", ->
    describe "when soft wrap is on", ->
      it "moves cursor to the beginning of the screen line", ->
        editor.setSoftWrapped(true)
        editor.setEditorWidthInChars(10)
        editor.setCursorScreenPosition([1, 2])
        editor.moveToBeginningOfScreenLine()
        cursor = editor.getLastCursor()
        expect(cursor.getScreenPosition()).toEqual [1, 0]

    describe "when soft wrap is off", ->
      it "moves cursor to the beginning of the line", ->
        editor.setCursorScreenPosition [0, 5]
        editor.addCursorAtScreenPosition [1, 7]
        editor.moveToBeginningOfScreenLine()
        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 0]
        expect(cursor2.getBufferPosition()).toEqual [1, 0]

  describe ".moveToEndOfScreenLine()", ->
    describe "when soft wrap is on", ->
      it "moves cursor to the beginning of the screen line", ->
        editor.setSoftWrapped(true)
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(10)
        editor.setCursorScreenPosition([1, 2])
        editor.moveToEndOfScreenLine()
        cursor = editor.getLastCursor()
        expect(cursor.getScreenPosition()).toEqual [1, 9]

    describe "when soft wrap is off", ->
      it "moves cursor to the end of line", ->
        editor.setCursorScreenPosition [0, 0]
        editor.addCursorAtScreenPosition [1, 0]
        editor.moveToEndOfScreenLine()
        expect(editor.getCursors().length).toBe 2
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 29]
        expect(cursor2.getBufferPosition()).toEqual [1, 30]

  describe ".moveToBeginningOfLine()", ->
    it "moves cursor to the beginning of the buffer line", ->
      editor.setSoftWrapped(true)
      editor.setDefaultCharWidth(1)
      editor.setEditorWidthInChars(10)
      editor.setCursorScreenPosition([1, 2])
      editor.moveToBeginningOfLine()
      cursor = editor.getLastCursor()
      expect(cursor.getScreenPosition()).toEqual [0, 0]

  describe ".moveToEndOfLine()", ->
    it "moves cursor to the end of the buffer line", ->
      editor.setSoftWrapped(true)
      editor.setDefaultCharWidth(1)
      editor.setEditorWidthInChars(10)
      editor.setCursorScreenPosition([0, 2])
      editor.moveToEndOfLine()
      cursor = editor.getLastCursor()
      expect(cursor.getScreenPosition()).toEqual [4, 4]

  describe ".moveToFirstCharacterOfLine()", ->
    describe "when soft wrap is on", ->
      it "moves to the first character of the current screen line or the beginning of the screen line if it's already on the first character", ->
        editor.setSoftWrapped(true)
        editor.setDefaultCharWidth(1)
        editor.setEditorWidthInChars(10)
        editor.setCursorScreenPosition [2, 5]
        editor.addCursorAtScreenPosition [8, 7]

        editor.moveToFirstCharacterOfLine()
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getScreenPosition()).toEqual [2, 0]
        expect(cursor2.getScreenPosition()).toEqual [8, 2]

        editor.moveToFirstCharacterOfLine()
        expect(cursor1.getScreenPosition()).toEqual [2, 0]
        expect(cursor2.getScreenPosition()).toEqual [8, 2]

    describe "when soft wrap is off", ->
      it "moves to the first character of the current line or the beginning of the line if it's already on the first character", ->
        editor.setCursorScreenPosition [0, 5]
        editor.addCursorAtScreenPosition [1, 7]

        editor.moveToFirstCharacterOfLine()
        [cursor1, cursor2] = editor.getCursors()
        expect(cursor1.getBufferPosition()).toEqual [0, 0]
        expect(cursor2.getBufferPosition()).toEqual [1, 2]

        editor.moveToFirstCharacterOfLine()
        expect(cursor1.getBufferPosition()).toEqual [0, 0]
        expect(cursor2.getBufferPosition()).toEqual [1, 0]

      it "moves to the beginning of the line if it only contains whitespace ", ->
        editor.setText("first\n    \nthird")
        editor.setCursorScreenPosition [1, 2]
        editor.moveToFirstCharacterOfLine()
        cursor = editor.getLastCursor()
        expect(cursor.getBufferPosition()).toEqual [1, 0]

      describe "when invisible characters are enabled with soft tabs", ->
        it "moves to the first character of the current line without being confused by the invisible characters", ->
          editor.update({showInvisibles: true})
          editor.setCursorScreenPosition [1, 7]
          editor.moveToFirstCharacterOfLine()
          expect(editor.getCursorBufferPosition()).toEqual [1, 2]
          editor.moveToFirstCharacterOfLine()
          expect(editor.getCursorBufferPosition()).toEqual [1, 0]

      describe "when invisible characters are enabled with hard tabs", ->
        it "moves to the first character of the current line without being confused by the invisible characters", ->
          editor.update({showInvisibles: true})
          buffer.setTextInRange([[1, 0], [1, Infinity]], '\t\t\ta', normalizeLineEndings: false)

          editor.setCursorScreenPosition [1, 7]
          editor.moveToFirstCharacterOfLine()
          expect(editor.getCursorBufferPosition()).toEqual [1, 3]
          editor.moveToFirstCharacterOfLine()
          expect(editor.getCursorBufferPosition()).toEqual [1, 0]

  describe ".moveToBeginningOfWord()", ->
    it "moves the cursor to the beginning of the word", ->
      editor.setCursorBufferPosition [0, 8]
      editor.addCursorAtBufferPosition [1, 12]
      editor.addCursorAtBufferPosition [3, 0]
      [cursor1, cursor2, cursor3] = editor.getCursors()

      editor.moveToBeginningOfWord()

      expect(cursor1.getBufferPosition()).toEqual [0, 4]
      expect(cursor2.getBufferPosition()).toEqual [1, 11]
      expect(cursor3.getBufferPosition()).toEqual [2, 39]

    it "does not fail at position [0, 0]", ->
      editor.setCursorBufferPosition([0, 0])
      editor.moveToBeginningOfWord()

    it "treats lines with only whitespace as a word", ->
      editor.setCursorBufferPosition([11, 0])
      editor.moveToBeginningOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    it "treats lines with only whitespace as a word (CRLF line ending)", ->
      editor.buffer.setText(buffer.getText().replace(/\n/g, "\r\n"))
      editor.setCursorBufferPosition([11, 0])
      editor.moveToBeginningOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    it "works when the current line is blank", ->
      editor.setCursorBufferPosition([10, 0])
      editor.moveToBeginningOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [9, 2]

    it "works when the current line is blank (CRLF line ending)", ->
      editor.buffer.setText(buffer.getText().replace(/\n/g, "\r\n"))
      editor.setCursorBufferPosition([10, 0])
      editor.moveToBeginningOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [9, 2]
      editor.buffer.setText(buffer.getText().replace(/\r\n/g, "\n"))

  describe ".moveToPreviousWordBoundary()", ->
    it "moves the cursor to the previous word boundary", ->
      editor.setCursorBufferPosition [0, 8]
      editor.addCursorAtBufferPosition [2, 0]
      editor.addCursorAtBufferPosition [2, 4]
      editor.addCursorAtBufferPosition [3, 14]
      [cursor1, cursor2, cursor3, cursor4] = editor.getCursors()

      editor.moveToPreviousWordBoundary()

      expect(cursor1.getBufferPosition()).toEqual [0, 4]
      expect(cursor2.getBufferPosition()).toEqual [1, 30]
      expect(cursor3.getBufferPosition()).toEqual [2, 0]
      expect(cursor4.getBufferPosition()).toEqual [3, 13]

  describe ".moveToNextWordBoundary()", ->
    it "moves the cursor to the previous word boundary", ->
      editor.setCursorBufferPosition [0, 8]
      editor.addCursorAtBufferPosition [2, 40]
      editor.addCursorAtBufferPosition [3, 0]
      editor.addCursorAtBufferPosition [3, 30]
      [cursor1, cursor2, cursor3, cursor4] = editor.getCursors()

      editor.moveToNextWordBoundary()

      expect(cursor1.getBufferPosition()).toEqual [0, 13]
      expect(cursor2.getBufferPosition()).toEqual [3, 0]
      expect(cursor3.getBufferPosition()).toEqual [3, 4]
      expect(cursor4.getBufferPosition()).toEqual [3, 31]

  describe ".moveToEndOfWord()", ->
    it "moves the cursor to the end of the word", ->
      editor.setCursorBufferPosition [0, 6]
      editor.addCursorAtBufferPosition [1, 10]
      editor.addCursorAtBufferPosition [2, 40]
      [cursor1, cursor2, cursor3] = editor.getCursors()

      editor.moveToEndOfWord()

      expect(cursor1.getBufferPosition()).toEqual [0, 13]
      expect(cursor2.getBufferPosition()).toEqual [1, 12]
      expect(cursor3.getBufferPosition()).toEqual [3, 7]

    it "does not blow up when there is no next word", ->
      editor.setCursorBufferPosition [Infinity, Infinity]
      endPosition = editor.getCursorBufferPosition()
      editor.moveToEndOfWord()
      expect(editor.getCursorBufferPosition()).toEqual endPosition

    it "treats lines with only whitespace as a word", ->
      editor.setCursorBufferPosition([9, 4])
      editor.moveToEndOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    it "treats lines with only whitespace as a word (CRLF line ending)", ->
      editor.buffer.setText(buffer.getText().replace(/\n/g, "\r\n"))
      editor.setCursorBufferPosition([9, 4])
      editor.moveToEndOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    it "works when the current line is blank", ->
      editor.setCursorBufferPosition([10, 0])
      editor.moveToEndOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [11, 8]

    it "works when the current line is blank (CRLF line ending)", ->
      editor.buffer.setText(buffer.getText().replace(/\n/g, "\r\n"))
      editor.setCursorBufferPosition([10, 0])
      editor.moveToEndOfWord()
      expect(editor.getCursorBufferPosition()).toEqual [11, 8]

  describe ".moveToBeginningOfNextWord()", ->
    it "moves the cursor before the first character of the next word", ->
      editor.setCursorBufferPosition [0, 6]
      editor.addCursorAtBufferPosition [1, 11]
      editor.addCursorAtBufferPosition [2, 0]
      [cursor1, cursor2, cursor3] = editor.getCursors()

      editor.moveToBeginningOfNextWord()

      expect(cursor1.getBufferPosition()).toEqual [0, 14]
      expect(cursor2.getBufferPosition()).toEqual [1, 13]
      expect(cursor3.getBufferPosition()).toEqual [2, 4]

      # When the cursor is on whitespace
      editor.setText("ab cde- ")
      editor.setCursorBufferPosition [0, 2]
      cursor = editor.getLastCursor()
      editor.moveToBeginningOfNextWord()

      expect(cursor.getBufferPosition()).toEqual [0, 3]

    it "does not blow up when there is no next word", ->
      editor.setCursorBufferPosition [Infinity, Infinity]
      endPosition = editor.getCursorBufferPosition()
      editor.moveToBeginningOfNextWord()
      expect(editor.getCursorBufferPosition()).toEqual endPosition

    it "treats lines with only whitespace as a word", ->
      editor.setCursorBufferPosition([9, 4])
      editor.moveToBeginningOfNextWord()
      expect(editor.getCursorBufferPosition()).toEqual [10, 0]

    it "works when the current line is blank", ->
      editor.setCursorBufferPosition([10, 0])
      editor.moveToBeginningOfNextWord()
      expect(editor.getCursorBufferPosition()).toEqual [11, 9]

  describe ".moveToPreviousSubwordBoundary", ->
    it "does not move the cursor when there is no previous subword boundary", ->
      editor.setText('')
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 0])

    it "stops at word and underscore boundaries", ->
      editor.setText("sub_word \n")
      editor.setCursorBufferPosition([0, 9])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 8])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 0])

      editor.setText(" word\n")
      editor.setCursorBufferPosition([0, 3])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    it "stops at camelCase boundaries", ->
      editor.setText(" getPreviousWord\n")
      editor.setCursorBufferPosition([0, 16])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 12])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    it "skips consecutive non-word characters", ->
      editor.setText("e, => \n")
      editor.setCursorBufferPosition([0, 6])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 3])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    it "skips consecutive uppercase characters", ->
      editor.setText(" AAADF \n")
      editor.setCursorBufferPosition([0, 7])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 6])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

      editor.setText("ALPhA\n")
      editor.setCursorBufferPosition([0, 4])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 2])

    it "skips consecutive numbers", ->
      editor.setText(" 88 \n")
      editor.setCursorBufferPosition([0, 4])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 3])

      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

    it "works with multiple cursors", ->
      editor.setText("curOp\ncursorOptions\n")
      editor.setCursorBufferPosition([0, 8])
      editor.addCursorAtBufferPosition([1, 13])
      [cursor1, cursor2] = editor.getCursors()

      editor.moveToPreviousSubwordBoundary()

      expect(cursor1.getBufferPosition()).toEqual([0, 3])
      expect(cursor2.getBufferPosition()).toEqual([1, 6])

    it "works with non-English characters", ->
      editor.setText("supåTøåst \n")
      editor.setCursorBufferPosition([0, 9])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

      editor.setText("supaÖast \n")
      editor.setCursorBufferPosition([0, 8])
      editor.moveToPreviousSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

  describe ".moveToNextSubwordBoundary", ->
    it "does not move the cursor when there is no next subword boundary", ->
      editor.setText('')
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 0])

    it "stops at word and underscore boundaries", ->
      editor.setText(" sub_word \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 9])

      editor.setText("word \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

    it "stops at camelCase boundaries", ->
      editor.setText("getPreviousWord \n")
      editor.setCursorBufferPosition([0, 0])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 3])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 11])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 15])

    it "skips consecutive non-word characters", ->
      editor.setText(", => \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

    it "skips consecutive uppercase characters", ->
      editor.setText(" AAADF \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 6])

      editor.setText("ALPhA\n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 2])

    it "skips consecutive numbers", ->
      editor.setText(" 88 \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 1])

      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 3])

    it "works with multiple cursors", ->
      editor.setText("curOp\ncursorOptions\n")
      editor.setCursorBufferPosition([0, 0])
      editor.addCursorAtBufferPosition([1, 0])
      [cursor1, cursor2] = editor.getCursors()

      editor.moveToNextSubwordBoundary()
      expect(cursor1.getBufferPosition()).toEqual([0, 3])
      expect(cursor2.getBufferPosition()).toEqual([1, 6])

    it "works with non-English characters", ->
      editor.setText("supåTøåst \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

      editor.setText("supaÖast \n")
      editor.setCursorBufferPosition([0, 0])
      editor.moveToNextSubwordBoundary()
      expect(editor.getCursorBufferPosition()).toEqual([0, 4])

  describe ".moveToBeginningOfNextParagraph()", ->
    it "moves the cursor before the first line of the next paragraph", ->
      editor.setCursorBufferPosition [0, 6]
      editor.foldBufferRow(4)

      editor.moveToBeginningOfNextParagraph()
      expect(editor.getCursorBufferPosition()).toEqual  [10, 0]

      editor.setText("")
      editor.setCursorBufferPosition [0, 0]
      editor.moveToBeginningOfNextParagraph()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

    it "moves the cursor before the first line of the next paragraph (CRLF line endings)", ->
      editor.setText(editor.getText().replace(/\n/g, '\r\n'))

      editor.setCursorBufferPosition [0, 6]
      editor.foldBufferRow(4)

      editor.moveToBeginningOfNextParagraph()
      expect(editor.getCursorBufferPosition()).toEqual  [10, 0]

      editor.setText("")
      editor.setCursorBufferPosition [0, 0]
      editor.moveToBeginningOfNextParagraph()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe ".moveToBeginningOfPreviousParagraph()", ->
    it "moves the cursor before the first line of the previous paragraph", ->
      editor.setCursorBufferPosition [10, 0]
      editor.foldBufferRow(4)

      editor.moveToBeginningOfPreviousParagraph()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

      editor.setText("")
      editor.setCursorBufferPosition [0, 0]
      editor.moveToBeginningOfPreviousParagraph()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

    it "moves the cursor before the first line of the previous paragraph (CRLF line endings)", ->
      editor.setText(editor.getText().replace(/\n/g, '\r\n'))

      editor.setCursorBufferPosition [10, 0]
      editor.foldBufferRow(4)

      editor.moveToBeginningOfPreviousParagraph()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

      editor.setText("")
      editor.setCursorBufferPosition [0, 0]
      editor.moveToBeginningOfPreviousParagraph()
      expect(editor.getCursorBufferPosition()).toEqual [0, 0]

  describe ".getCurrentParagraphBufferRange()", ->
    it "returns the buffer range of the current paragraph, delimited by blank lines or the beginning / end of the file", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

      runs ->
        buffer.setText """
            I am the first paragraph,
          bordered by the beginning of
          the file
          #{'   '}

            I am the second paragraph
          with blank lines above and below
          me.

          I am the last paragraph,
          bordered by the end of the file.
        """

        # in a paragraph
        editor.setCursorBufferPosition([1, 7])
        expect(editor.getCurrentParagraphBufferRange()).toEqual [[0, 0], [2, 8]]

        editor.setCursorBufferPosition([7, 1])
        expect(editor.getCurrentParagraphBufferRange()).toEqual [[5, 0], [7, 3]]

        editor.setCursorBufferPosition([9, 10])
        expect(editor.getCurrentParagraphBufferRange()).toEqual [[9, 0], [10, 32]]

        # between paragraphs
        editor.setCursorBufferPosition([3, 1])
        expect(editor.getCurrentParagraphBufferRange()).toBeUndefined()

  describe "getCursorAtScreenPosition(screenPosition)", ->
    it "returns the cursor at the given screenPosition", ->
      cursor1 = editor.addCursorAtScreenPosition([0, 2])
      cursor2 = editor.getCursorAtScreenPosition(cursor1.getScreenPosition())
      expect(cursor2).toBe cursor1

  describe "::getCursorScreenPositions()", ->
    it "returns the cursor positions in the order they were added", ->
      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

      runs ->
        editor.foldBufferRow(4)
        cursor1 = editor.addCursorAtBufferPosition([8, 5])
        cursor2 = editor.addCursorAtBufferPosition([3, 5])
        expect(editor.getCursorScreenPositions()).toEqual [[0, 0], [5, 5], [3, 5]]

  describe "::getCursorsOrderedByBufferPosition()", ->
    it "returns all cursors ordered by buffer positions", ->
      originalCursor = editor.getLastCursor()
      cursor1 = editor.addCursorAtBufferPosition([8, 5])
      cursor2 = editor.addCursorAtBufferPosition([4, 5])
      expect(editor.getCursorsOrderedByBufferPosition()).toEqual [originalCursor, cursor2, cursor1]

  describe "addCursorAtScreenPosition(screenPosition)", ->
    describe "when a cursor already exists at the position", ->
      it "returns the existing cursor", ->
        cursor1 = editor.addCursorAtScreenPosition([0, 2])
        cursor2 = editor.addCursorAtScreenPosition([0, 2])
        expect(cursor2).toBe cursor1

  describe "addCursorAtBufferPosition(bufferPosition)", ->
    describe "when a cursor already exists at the position", ->
      it "returns the existing cursor", ->
        cursor1 = editor.addCursorAtBufferPosition([1, 4])
        cursor2 = editor.addCursorAtBufferPosition([1, 4])
        expect(cursor2.marker).toBe cursor1.marker

  describe '.getCursorScope()', ->
    it 'returns the current scope', ->
      waitsForPromise ->
        atom.packages.activatePackage('language-javascript')

      runs ->
        descriptor = editor.getCursorScope()
        expect(descriptor.scopes).toContain('source.js')
