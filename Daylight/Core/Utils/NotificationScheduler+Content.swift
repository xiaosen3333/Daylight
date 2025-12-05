import UserNotifications

extension NotificationScheduler {
    func makeDayContent(context: NotificationContext, dayKey: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let hasCommitment = context.hasCommitmentToday
        let nickname = trimmed(context.nickname)

        if hasCommitment {
            if let name = nickname {
                content.title = localized("notification.day.withCommitment.title.nickname", name)
                content.body = localized("notification.day.withCommitment.body.nickname")
            } else {
                content.title = localized("notification.day.withCommitment.title")
                content.body = localized("notification.day.withCommitment.body")
            }
        } else {
            if let name = nickname {
                content.title = localized("notification.day.noCommitment.title.nickname", name)
                content.body = localized("notification.day.noCommitment.body.nickname")
            } else {
                content.title = localized("notification.day.noCommitment.title")
                content.body = localized("notification.day.noCommitment.body")
            }
        }
        var info: [String: String] = ["deeplink": "day"]
        if let key = dayKey { info["dayKey"] = key }
        content.userInfo = info
        return content
    }

    func makeNightContent(round: Int, context: NotificationContext, dayKey: String?) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let nickname = trimmed(context.nickname)
        let previewAvailable = context.showCommitmentInNotification && hasText(context.commitmentPreview)
        let preview = context.commitmentPreview ?? ""
        let isFirstRound = round == 1
        if isFirstRound {
            if previewAvailable {
                if let name = nickname {
                    content.title = localized("notification.night.first.title.nickname", name)
                    content.body = localized("notification.night.first.body.nickname", preview)
                } else {
                    content.title = localized("notification.night.first.title")
                    content.body = localized("notification.night.first.body", preview)
                }
            } else {
                if let name = nickname {
                    content.title = localized("notification.night.first.noCommitment.title.nickname", name)
                    content.body = localized("notification.night.first.noCommitment.body.nickname")
                } else {
                    content.title = localized("notification.night.first.noCommitment.title")
                    content.body = localized("notification.night.first.noCommitment.body")
                }
            }
        } else {
            if previewAvailable {
                if let name = nickname {
                    content.title = localized("notification.night.second.title.nickname", name)
                    content.body = localized("notification.night.second.body.nickname", preview)
                } else {
                    content.title = localized("notification.night.second.title")
                    content.body = localized("notification.night.second.body", preview)
                }
            } else {
                if let name = nickname {
                    content.title = localized("notification.night.second.noCommitment.title.nickname", name)
                    content.body = localized("notification.night.second.noCommitment.body.nickname")
                } else {
                    content.title = localized("notification.night.second.noCommitment.title")
                    content.body = localized("notification.night.second.noCommitment.body")
                }
            }
        }
        var info: [String: String] = ["deeplink": "night"]
        if let key = dayKey { info["dayKey"] = key }
        content.userInfo = info
        return content
    }

    private func localized(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, comment: "")
        return String(format: format, locale: Locale.autoupdatingCurrent, arguments: args)
    }

    private func trimmed(_ text: String?) -> String? {
        guard let trimmedText = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedText.isEmpty else { return nil }
        return trimmedText
    }

    private func hasText(_ text: String?) -> Bool {
        trimmed(text) != nil
    }
}
