EisConfigView = require './eis-config-view'
{CompositeDisposable} = require 'atom'

module.exports = EisConfig =
  eisConfigView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @eisConfigView = new EisConfigView(state.eisConfigViewState)

    @modalPanel = atom.workspace.addModalPanel(item: @eisConfigView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # @subscriptions.add atom.commands.add 'atom-workspace', 'eis-config:toggle': =>

    atom.workspace.observeActivePaneItem (editor) => @determineAction(editor)


  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @eisConfigView.destroy()

  determineAction: (editor) ->
    if @isConfigFile(editor.getTitle())
      console.log 'Searching for duplicates in ' + editor.getTitle()
      @doAction()

  isConfigFile: (fileName) ->
    return fileName.endsWith('.config')

  serialize: ->
    eisConfigViewState: @eisConfigView.serialize()

  splitValue: (text, index, lineNumber) ->
    return {key: text.substring(0, index), value: text.substring(index+1), rowNum: lineNumber}


  toggle: ->
    if @modalPanel.isVisible()
      #@modalPanel.hide()
    else
      @doAction()

  doAction: ->
    lines = @getCurrentEditorLines()
    configurationParameters = @parseConfigFile(lines)
    duplicateKeysCount = 0
    for key, propertyValues of configurationParameters
      if propertyValues.length > 1
        duplicateKeysCount++
        console.log "'" + key + '\' has duplicates: ' + propertyValues.length
        console.log 'values : '
        for propertyValue in propertyValues
          console.log propertyValue.value + ' on line: ' + propertyValue.rowNum
    if duplicateKeysCount > 0
      atom.beep()
      @eisConfigView.setCount(duplicateKeysCount)
      @eisConfigView.displayDialog()

  getCurrentEditorLines: ->
    editor = atom.workspace.getActiveTextEditor();
    return editor.getText().split(/\n/)

  processLine: (fileLine, i) ->
    line = fileLine.trim()
    if line.length && !line.startsWith("#")
      equalsPos = line.indexOf('=')
      if equalsPos != -1
        return @splitValue(line, equalsPos, i)

  parseConfigFile: (lines) ->
    configurationParameters = {}
    for i in [0..lines.length-1]
      currentParam = @processLine(lines[i], i+1)
      if currentParam
        keyValues = configurationParameters[currentParam.key]
        if keyValues !instanceof Array
          keyValues = []
          configurationParameters[currentParam.key] = keyValues
        keyValues.push(currentParam)
    return configurationParameters
