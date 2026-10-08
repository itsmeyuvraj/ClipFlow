import SwiftUI
import AppKit

public struct VideoHeroCard: View {
    public let video: VideoInfo

    public var body: some View {
        GlassCard(cornerRadius: 14, padding: 14) {
            HStack(alignment: .top, spacing: 16) {
                // Thumbnail with Duration Overlay
                ZStack(alignment: .bottomTrailing) {
                    if let thumbUrl = video.thumbnail, let url = URL(string: thumbUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    )
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(16/9, contentMode: .fill)
                            case .failure:
                                Rectangle()
                                    .fill(Color.primary.opacity(0.06))
                                    .overlay(
                                        Image(systemName: "film")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        Rectangle()
                            .fill(Color.primary.opacity(0.06))
                            .overlay(
                                Image(systemName: "film")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            )
                    }

                    // Duration Badge
                    Text(video.formattedDuration)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Color.black.opacity(0.75)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .padding(6)
                }
                .frame(width: 190, height: 107)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)

                // Video Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(video.title)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(.primary)

                        Spacer()

                        Button(action: {
                            if let url = URL(string: video.webpageUrl) {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Open in Browser")
                    }

                    // Channel & Views
                    HStack(spacing: 8) {
                        Label(video.authorName, systemImage: "person.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        if !video.formattedViewCount.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(video.formattedViewCount)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        if !video.formattedUploadDate.isEmpty {
                            Text("•")
                                .foregroundColor(.secondary.opacity(0.5))
                            Text(video.formattedUploadDate)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Stream capabilities pill row
                    HStack(spacing: 6) {
                        if let maxRes = video.availableResolutions.first {
                            StatusBadge(
                                text: maxRes >= 2160 ? "4K UHD" : (maxRes >= 1080 ? "1080p HD" : "\(maxRes)p"),
                                icon: "tv.fill",
                                color: maxRes >= 1080 ? .red : .blue
                            )
                        }

                        let totalStreams = video.validFormats.count
                        StatusBadge(
                            text: "\(totalStreams) Formats Available",
                            icon: "list.bullet",
                            color: .secondary
                        )

                        if !video.audioFormats.isEmpty {
                            StatusBadge(
                                text: "Audio Stored",
                                icon: "waveform",
                                color: .purple
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
