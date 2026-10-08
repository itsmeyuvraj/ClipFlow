import SwiftUI

public struct FormatPickerView: View {
    public let video: VideoInfo
    @Binding public var category: DownloadTargetCategory
    @Binding public var selectedPreset: QualityPreset
    @Binding public var selectedVideoContainer: VideoContainerFormat
    @Binding public var selectedAudioContainer: AudioContainerFormat
    @Binding public var selectedCustomFormatId: String?
    public let onTriggerDownload: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Category Tabs
            HStack(spacing: 8) {
                ForEach(DownloadTargetCategory.allCases) { cat in
                    Button(action: {
                        category = cat
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 12))
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .foregroundColor(category == cat ? .white : .primary)
                        .background(
                            category == cat
                                ? AnyView(Capsule().fill(Color.accentColor))
                                : AnyView(Capsule().fill(Color.primary.opacity(0.06)))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            // Tab Content
            switch category {
            case .video:
                videoPresetSection

            case .audio:
                audioSection

            case .customStream:
                AllFormatsTableView(
                    video: video,
                    selectedFormatId: $selectedCustomFormatId,
                    onSelectAndDownload: { _ in
                        onTriggerDownload()
                    }
                )
            }
        }
    }

    // MARK: - Video Presets Grid
    private var videoPresetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Container Format Selector
            HStack(spacing: 8) {
                Text("Container:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Picker("Container", selection: $selectedVideoContainer) {
                    ForEach(VideoContainerFormat.allCases) { container in
                        Text(container.displayName).tag(container)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 240)

                Spacer()
            }

            // Quality Presets
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(QualityPreset.allCases) { preset in
                    let isAvailable = isPresetAvailable(preset)
                    let isSelected = selectedPreset == preset

                    Button(action: {
                        if isAvailable {
                            selectedPreset = preset
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(preset.badgeLabel)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(isSelected ? .white : (isAvailable ? .primary : .secondary.opacity(0.5)))
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                }
                            }

                            Text(preset.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(isSelected ? .white.opacity(0.85) : (isAvailable ? .secondary : .secondary.opacity(0.4)))
                                .lineLimit(1)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.accentColor : (isAvailable ? Color.primary.opacity(0.04) : Color.primary.opacity(0.01)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                }
            }
        }
    }

    private func isPresetAvailable(_ preset: QualityPreset) -> Bool {
        guard let maxHeight = preset.maxHeight else { return true }
        guard let videoMax = video.availableResolutions.first else { return true }
        // If the video's highest available resolution is at least 360, allow presets up to the max height
        // e.g. a 720p video shouldn't show 4K as available
        return videoMax >= (maxHeight * 8 / 10) // generous tolerance for e.g. 1080 vs 1072
    }

    // MARK: - Audio Section
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Audio Format (Extracted at Highest Available Bitrate):")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(AudioContainerFormat.allCases) { audio in
                    let isSelected = selectedAudioContainer == audio
                    Button(action: {
                        selectedAudioContainer = audio
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: audio == .flac || audio == .wav ? "waveform.badge.magnifyingglass" : "music.note")
                                .font(.system(size: 14))
                                .foregroundColor(isSelected ? .white : .purple)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(audio.displayName)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(isSelected ? .white : .primary)
                                Text(audioDescription(audio))
                                    .font(.system(size: 10))
                                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.purple : Color.primary.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? Color.purple : Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func audioDescription(_ audio: AudioContainerFormat) -> String {
        switch audio {
        case .mp3: return "Universal MP3"
        case .m4a: return "Apple AAC Native"
        case .flac: return "Lossless Quality"
        case .wav: return "Uncompressed PCM"
        case .opus: return "High Efficiency"
        }
    }
}
