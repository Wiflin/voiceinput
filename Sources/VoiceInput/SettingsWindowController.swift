import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings
    private let baseURLField = NSTextField()
    private let apiKeyField = NSSecureTextField()
    private let modelField = NSTextField()
    private let testButton = NSButton(title: "Test", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private let refiner = LLMRefiner()

    init(settings: AppSettings) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLM Refinement Settings"
        window.center()
        super.init(window: window)
        setupUI()
        loadSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let form = NSGridView()
        form.translatesAutoresizingMaskIntoConstraints = false
        form.rowSpacing = 12
        form.columnSpacing = 12

        let baseLabel = NSTextField(labelWithString: "API Base URL")
        let keyLabel = NSTextField(labelWithString: "API Key")
        let modelLabel = NSTextField(labelWithString: "Model")

        [baseURLField, apiKeyField, modelField].forEach { field in
            field.translatesAutoresizingMaskIntoConstraints = false
            field.font = .systemFont(ofSize: 13)
            field.bezelStyle = .roundedBezel
        }

        apiKeyField.placeholderString = "Paste API key, or clear this field to remove it"
        baseURLField.placeholderString = "https://api.openai.com/v1"
        modelField.placeholderString = "gpt-4o-mini"

        form.addRow(with: [baseLabel, baseURLField])
        form.addRow(with: [keyLabel, apiKeyField])
        form.addRow(with: [modelLabel, modelField])
        form.column(at: 0).xPlacement = .trailing
        form.column(at: 1).width = 340

        testButton.target = self
        testButton.action = #selector(testSettings)
        saveButton.target = self
        saveButton.action = #selector(saveSettings)
        saveButton.keyEquivalent = "\r"

        let buttonStack = NSStackView(views: [statusLabel, testButton, saveButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .centerY

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        contentView.addSubview(form)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            form.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            form.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            form.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),

            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 230)
        ])
    }

    private func loadSettings() {
        baseURLField.stringValue = settings.apiBaseURL
        apiKeyField.stringValue = settings.apiKey
        modelField.stringValue = settings.model
    }

    @objc private func saveSettings() {
        settings.apiBaseURL = baseURLField.stringValue
        settings.apiKey = apiKeyField.stringValue
        settings.model = modelField.stringValue
        statusLabel.stringValue = "Saved"
    }

    @objc private func testSettings() {
        saveSettings()
        statusLabel.stringValue = "Testing..."
        testButton.isEnabled = false

        Task {
            let result = await refiner.refine(
                text: "请用配森解析杰森数据",
                baseURL: settings.apiBaseURL,
                apiKey: settings.apiKey,
                model: settings.model
            )
            await MainActor.run {
                testButton.isEnabled = true
                statusLabel.stringValue = result.contains("Python") || result.contains("JSON") ? "Test passed" : "Response received"
            }
        }
    }
}
