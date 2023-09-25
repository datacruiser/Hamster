//
//  NumericNineGridKeyboard.swift
//
//
//  Created by morse on 2023/9/5.
//

import Combine
import HamsterKit
import UIKit

/// 数字九宫格键盘
public class NumericNineGridKeyboard: UIView, UICollectionViewDelegate {
  // MARK: - Properties

  private let keyboardLayoutProvider: NumericNineGridKeyboardLayoutProvider
  private let actionHandler: KeyboardActionHandler
  private let appearance: KeyboardAppearance
  private var keyboardContext: KeyboardContext
  private var calloutContext: KeyboardCalloutContext
  private var rimeContext: RimeContext

  /// 符号列表视图
  private lazy var symbolsListView: SymbolsVerticalView = {
    let view = SymbolsVerticalView(
      keyboardContext: keyboardContext,
      actionHandler: actionHandler,
      initDataBuilder: {
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(keyboardContext.symbolsOfNumericNineGridKeyboard, toSection: 0)
        $0.apply(snapshot, animatingDifferences: false)
      }
    )
    view.delegate = self
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
  }()

  /// 符号列表容器视图
  private lazy var symbolsListContainerView: UIView = {
    // 九宫格自身的 insets
    let insets = keyboardLayoutProvider.insets

    let container = UIView(frame: .zero)
    container.backgroundColor = .clear
    container.translatesAutoresizingMaskIntoConstraints = false

    container.addSubview(symbolsListView)
    NSLayoutConstraint.activate([
      symbolsListView.topAnchor.constraint(equalTo: container.topAnchor, constant: insets.top),
      symbolsListView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -insets.bottom),
      symbolsListView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: insets.left),
      symbolsListView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -insets.right),
    ])
    return container
  }()

  // combine
  private var subscriptions = Set<AnyCancellable>()

  /// 缓存所有按键视图
  private var keyboardRows: [[KeyboardButton]] = []

  /// 静态视图约束，视图创建完毕后不在发生变化
  private var staticConstraints: [NSLayoutConstraint] = []

  /// 动态视图约束，在键盘方向发生变化后需要更新约束
  private var dynamicConstraints: [NSLayoutConstraint] = []

  // MARK: - 计算属性

  private var layout: KeyboardLayout {
    keyboardLayoutProvider.keyboardLayout(for: keyboardContext)
  }

  private var layoutConfig: KeyboardLayoutConfiguration {
    .standard(for: keyboardContext)
  }

  // MARK: - Initialization

  init(
    actionHandler: KeyboardActionHandler,
    appearance: KeyboardAppearance,
    keyboardContext: KeyboardContext,
    calloutContext: KeyboardCalloutContext,
    rimeContext: RimeContext
  ) {
    self.keyboardLayoutProvider = NumericNineGridKeyboardLayoutProvider(keyboardContext: keyboardContext)
    self.actionHandler = actionHandler
    self.appearance = appearance
    self.keyboardContext = keyboardContext
    self.calloutContext = calloutContext
    self.rimeContext = rimeContext

    super.init(frame: .zero)

    setupKeyboardView()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Layout

  func setupKeyboardView() {
    backgroundColor = .clear

    constructViewHierarchy()
    activateViewConstraints()

    // 屏幕方向改变调整行高
    keyboardContext.$interfaceOrientation
      .receive(on: DispatchQueue.main)
      .sink { [unowned self] _ in
        setNeedsUpdateConstraints()
      }
      .store(in: &subscriptions)
  }

  open func constructViewHierarchy() {
    // 添加右侧符号划动列表
    addSubview(symbolsListContainerView)

    // 添加按键
    for (rowIndex, row) in layout.itemRows.enumerated() {
      var tempRow = [KeyboardButton]()
      for (itemIndex, item) in row.enumerated() {
        let buttonItem = KeyboardButton(
          row: rowIndex,
          column: itemIndex,
          item: item,
          actionHandler: actionHandler,
          keyboardContext: keyboardContext,
          rimeContext: rimeContext,
          calloutContext: calloutContext,
          appearance: appearance
        )
        buttonItem.translatesAutoresizingMaskIntoConstraints = false
        // 需要将按键添加至 touchView, 统一处理
        addSubview(buttonItem)
        tempRow.append(buttonItem)
      }
      keyboardRows.append(tempRow)
    }
  }

  open func activateViewConstraints() {
    // 根据 keyboardContext 获取当前布局配置
    // 注意：临时变量缓存计算属性的值，避免重复计算
    let layoutConfig = layoutConfig

    // 键盘两侧按键宽度,其余按键平分剩余宽度
    let edgeButtonWidth = keyboardLayoutProvider.smallBottomWidth(for: keyboardContext)

    // 暂存中间部分按键，用于平分剩余宽度
    var availableItems = [KeyboardButton]()

    // 暂存前一个按键，用于按键之间的约束
    var prevItem: KeyboardButton?

    // 暂存上一行的按键，用于按键 y 轴约束
    var prevRowItem: KeyboardButton?

    // 左侧符号栏约束
    staticConstraints.append(symbolsListContainerView.topAnchor.constraint(equalTo: topAnchor))
    staticConstraints.append(symbolsListContainerView.leadingAnchor.constraint(equalTo: leadingAnchor))
    dynamicConstraints.append(symbolsListContainerView.heightAnchor.constraint(equalToConstant: layoutConfig.rowHeight * 3))

    for row in keyboardRows {
      for button in row {
        // 按键高度约束（高度包含 insets 部分）
        let buttonHeightConstraint = button.heightAnchor.constraint(equalToConstant: layoutConfig.rowHeight)
        buttonHeightConstraint.identifier = "\(button.row)-\(button.column)-button-height"
        // 注意：必须设置高度约束的优先级，Autolayout 会根据此约束自动更新根视图的高度，否则会与系统自动添加的约束冲突，会有错误日志输出。
        buttonHeightConstraint.priority = .defaultHigh
        dynamicConstraints.append(buttonHeightConstraint)

        // 按键宽度约束
        // 注意：最后一行的第一个按钮和每行最后一个按键的宽度是固定的，其他按键的宽度是平分的
        if (button.column == 0 && button.row + 1 == keyboardRows.endIndex) || button.column + 1 == row.endIndex {
          dynamicConstraints.append(button.widthAnchor.constraint(equalTo: widthAnchor, multiplier: edgeButtonWidth.percentageValue!))
        } else {
          availableItems.append(button)
        }

        if button.row == 0 {
          // 首行添加按键相对视图的 top 约束
          staticConstraints.append(button.topAnchor.constraint(equalTo: topAnchor))
        } else {
          // 最后一行的第一列添加相对划动符号列的 top 约束
          if button.column == 0, button.row + 1 == keyboardRows.endIndex {
            staticConstraints.append(button.topAnchor.constraint(equalTo: symbolsListContainerView.bottomAnchor))
            staticConstraints.append(symbolsListContainerView.widthAnchor.constraint(equalTo: button.widthAnchor))
          } else if let prevRowItem = prevRowItem { // 其他列添加相对上一行的符号约束
            // 其他行添加按键相对上一行按键的 top 约束
            staticConstraints.append(button.topAnchor.constraint(equalTo: prevRowItem.bottomAnchor))
          }

          // 最后一行添加按键相对视图的 bottom 约束
          if button.row + 1 == keyboardRows.endIndex {
            staticConstraints.append(button.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor))
          }
        }

        // 首列按键添加相对划动符号视图的 leading 约束
        if button.column == 0, button.row + 1 == keyboardRows.endIndex {
          staticConstraints.append(button.leadingAnchor.constraint(equalTo: leadingAnchor))
        } else if button.column == 0 {
          staticConstraints.append(button.leadingAnchor.constraint(equalTo: symbolsListContainerView.trailingAnchor))
        } else {
          // 其他列按键添加相对与前一个按键的 leading 约束
          if let prevItem = prevItem {
            staticConstraints.append(button.leadingAnchor.constraint(equalTo: prevItem.trailingAnchor))
          }

          if button.column + 1 == row.endIndex {
            // 最后一列按键添加相对行的 trailing 约束
            staticConstraints.append(button.trailingAnchor.constraint(equalTo: trailingAnchor))

            // 修改上一行 prevRowItem 变量引用
            prevRowItem = button
          }
        }

        // 修改上一个按键的引用，用于其他按键添加 leading 约束
        prevItem = button
      }
    }

    if let firstItem = availableItems.first {
      for item in availableItems.dropFirst() {
        staticConstraints.append(item.widthAnchor.constraint(equalTo: firstItem.widthAnchor))
      }
    }

    NSLayoutConstraint.activate(staticConstraints + dynamicConstraints)
  }
}

public extension NumericNineGridKeyboard {
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    let symbol = symbolsListView.diffalbeDataSource.snapshot(for: indexPath.section).items[indexPath.item]
    actionHandler.handle(.press, on: .symbol(.init(char: symbol)))
    return true
  }

  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    let symbol = symbolsListView.diffalbeDataSource.snapshot(for: indexPath.section).items[indexPath.item]
    actionHandler.handle(.release, on: .symbol(.init(char: symbol)))
    collectionView.deselectItem(at: indexPath, animated: true)
  }
}
