//
//  ToggleTableViewCell.swift
//  Hamster
//
//  Created by morse on 2023/6/14.
//

import HamsterUIKit
import UIKit

class ToggleTableViewCell: NibLessTableViewCell {
  static let identifier = "ToggleTableViewCell"

  // MARK: - properties

  override var configurationState: UICellConfigurationState {
    var state = super.configurationState
    state.settingItemModel = self.settingItem
    return state
  }

  lazy var switchView: UISwitch = {
    let switchView = UISwitch(frame: .zero)
    switchView.addTarget(self, action: #selector(toggleAction), for: .valueChanged)
    return switchView
  }()

  public var settingItem: SettingItemModel? = nil

  // MARK: - methods

  func updateWithSettingItem(_ item: SettingItemModel) {
    guard settingItem != item else { return }
    self.settingItem = item
    setNeedsUpdateConfiguration()
  }

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    accessoryView = switchView
  }

  @objc func toggleAction(_ sender: UISwitch) {
    settingItem?.toggleValue = sender.isOn
    settingItem?.toggleHandled?(sender.isOn)
  }

  override func updateConfiguration(using state: UICellConfigurationState) {
    super.updateConfiguration(using: state)

    var config = UIListContentConfiguration.cell()
    config.text = state.settingItemModel?.text
    config.secondaryText = state.settingItemModel?.secondaryText
    if let toggleValue = state.settingItemModel?.toggleValue {
      switchView.setOn(toggleValue, animated: false)
    }
    contentConfiguration = config
  }
}
