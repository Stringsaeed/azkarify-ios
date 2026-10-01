import SwiftUI

struct SearchFieldTypography: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> Controller { Controller() }

  func updateUIViewController(_ controller: Controller, context: Context) {
    controller.applyFont()
  }

  final class Controller: UIViewController {
    override func viewDidLoad() {
      super.viewDidLoad()
      view.isUserInteractionEnabled = false
      registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) {
        (controller: Controller, _: UITraitCollection) in
        controller.applyFont()
      }
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      applyFont()
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      applyFont()
    }

    func applyFont() {
      guard let baseFont = UIFont(name: "AlanSans-Regular", size: 17) else { return }
      var ancestor = parent
      while let controller = ancestor {
        if let field = controller.navigationItem.searchController?.searchBar.searchTextField {
          let font = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: baseFont, compatibleWith: field.traitCollection)
          if field.font != font { field.font = font }
          field.adjustsFontForContentSizeCategory = true
          if let placeholder = field.attributedPlaceholder, placeholder.length > 0,
            placeholder.attribute(.font, at: 0, effectiveRange: nil) as? UIFont != font
          {
            let styled = NSMutableAttributedString(attributedString: placeholder)
            styled.addAttribute(
              .font, value: font, range: NSRange(location: 0, length: styled.length))
            field.attributedPlaceholder = styled
          }
          return
        }
        ancestor = controller.parent
      }
    }
  }
}
