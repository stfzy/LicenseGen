import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        // 注册 JS Bridge
        config.userContentController.add(self, name: "downloadFile")

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.scrollView.bounces = false
        view.addSubview(webView)

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    // 接收 JS 消息
    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        guard message.name == "downloadFile",
              let body = message.body as? [String: String],
              let content = body["content"],
              let filename = body["filename"] else { return }

        // 写到临时目录
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent(filename)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            // 写文件失败，通知 JS
            webView.evaluateJavaScript("showToast('文件写入失败: \(error.localizedDescription)')")
            return
        }

        // 弹出系统分享面板
        DispatchQueue.main.async {
            let ac = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            // iPad 需要指定 sourceView，iPhone 上无效但不影响
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
