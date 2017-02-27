import { SwitchTextTypeCommand } from 'substance'
import MinimalSwitchTextTypeTool from './MinimalSwitchTextTypeTool'

export default {
  name: 'minimal-switch-text-type',
  configure: function(config) {
    config.addToolGroup('text')
    config.addCommand('minimal-switch-text-type', SwitchTextTypeCommand, {
      disableCollapsedCursor: true
    })
    config.addTool('minimal-switch-text-type', MinimalSwitchTextTypeTool, {
      toolGroup: 'text'
    })

    config.addLabel('paragraph', 'P')
    config.addLabel('heading1', 'H1')
    config.addLabel('heading2', 'H2')
    config.addLabel('heading3', 'H3')

  }
}
