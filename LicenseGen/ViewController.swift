import UIKit
import WebKit

// 解决循环引用问题
class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // 用弱引用方式注册，避免循环引用导致注册失败
        config.userContentController.add(WeakScriptMessageHandler(delegate: self), name: "downloadFile")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard message.name == "downloadFile",
              let body = message.body as? [String: String],
              let content = body["content"],
              let filename = body["filename"] else { return }

        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            let msg = error.localizedDescription.replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("showToast('\(msg)')")
            return
        }

        DispatchQueue.main.async {
            let ac = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = ac.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(
                    x: self.view.bounds.midX,
                    y: self.view.bounds.midY,
                    width: 0, height: 0
                )
            }
            self.present(ac, animated: true)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
}
