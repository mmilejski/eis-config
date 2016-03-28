EisConfigView = require './eis-config-view'
{CompositeDisposable} = require 'atom'

module.exports = EisConfig =
  eisConfigView: null
  modalPanel: null
  subscriptions: null

  serialize: ->
    eisConfigViewState: @eisConfigView.serialize()

  activate: (state) ->
    @eisConfigView = new EisConfigView(state.eisConfigViewState)

    @modalPanel = atom.workspace.addModalPanel(item: @eisConfigView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    # @subscriptions.add atom.commands.add 'atom-workspace', 'eis-config:toggle': =>

    atom.workspace.observeActivePaneItem (editor) => @determineAction(editor.getTitle())

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @eisConfigView.destroy()

  determineAction: (fileName) ->
    if @isConfigFile(fileName)
      console.log 'Searching for duplicates in ' + fileName
      @findDuplicateKeys()

  isConfigFile: (fileName) ->
    return fileName.endsWith('.config')

  splitValue: (text, index, lineNumber) ->
    return {key: text.substring(0, index), value: text.substring(index+1), rowNum: lineNumber}

  toggle: ->
    if @modalPanel.isVisible()
      #@modalPanel.hide()
    else
      @findDuplicateKeys()

  findDuplicateKeys: ->
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

  validateConfigurationEntry: (entry) ->
    entry = entry.trim();

    entryObject =
      valid: false,
      equalsPos: -1,
      content: entry

    if entry.length == 0
      return entryObject

    if entry.startsWith("#")
      return entryObject

    equalsPos = entry.indexOf('=')
    if equalsPos == -1
      return entryObject

    entryObject.equalsPos = equalsPos
    entryObject.valid = true

    return entryObject


  processLine: (line, lineNumber) ->
    lineObject = @validateConfigurationEntry(line)
    if lineObject.valid
        paramObject =
          key: lineObject.content.substring(0, lineObject.equalsPos),
          value: lineObject.content.substring(lineObject.equalsPos+1),
          rowNum: lineNumber
        return paramObject

  pushParameterValue: (parameter, configurationParameters) ->
    keyValues = configurationParameters[parameter.key]
    if keyValues !instanceof Array
      keyValues = []
      configurationParameters[parameter.key] = keyValues
    keyValues.push(parameter)

  parseConfigFile: (lines) ->
    configurationParameters = {}
    for i in [0..lines.length-1]
      if currentParam = @processLine(lines[i], i+1)
        @pushParameterValue(currentParam, configurationParameters)
    return configurationParameters
