import SwiftUI

public struct AllFormatsTableView: View {
    public let video: VideoInfo
    @Binding public var selectedFormatId: String?
    public let onSelectAndDownload: ((FormatItem) -> Void)?

    @State private var streamFilter: FilterType = .all
    @State private var searchQuery: String = ""

    public enum FilterType: String, CaseIterable, Identifiable {
        case all = "All Streams"
        case video = "Video Streams"
        case audio = "Audio Only"
        case muxed = "Muxed (Direct)"

        public var id: String { rawValue }
    }

    private var filteredFormats: [FormatItem] {
        video.validFormats.filter { item in
            // Filter by type
            switch streamFilter {
            case .all:
                break
            case .video:
                if item.isAudioOnly { return false }
            case .audio:
                if !item.isAudioOnly { return false }
            case .muxed:
                if !item.isMuxedVideoAndAudio { return false }
            }

            // Filter by search query
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let matchId = item.formatId.lowercased().contains(q)
                let matchExt = item.ext.lowercased().contains(q)
                let matchRes = item.resolution?.lowercased().contains(q) ?? false
                let matchNote = item.formatNote?.lowercased().contains(q) ?? false
                let matchVcodec = item.vcodec?.lowercased().contains(q) ?? false
                let matchAcodec = item.acodec?.lowercased().contains(q) ?? false
                return matchId || matchExt || matchRes || matchNote || matchVcodec || matchAcodec
            }

            return true
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Controls header: Filter selector & Search bar
            HStack(spacing: 12) {
                Picker("Filter", selection: $streamFilter) {
                    ForEach(FilterType.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Search codec, ext, res...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .frame(width: 200)
            }

            // Streams Table / List
            VStack(spacing: 0) {
                // Table Column Header
                HStack(spacing: 10) {
                    Text("FORMAT ID")
                        .frame(width: 80, alignment: .leading)
                    Text("TYPE")
                        .frame(width: 100, alignment: .leading)
                    Text("RESOLUTION / NOTE")
                        .frame(width: 150, alignment: .leading)
                    Text("EXT")
                        .frame(width: 60, alignment: .leading)
                    Text("CODECS")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("EST. SIZE")
                        .frame(width: 90, alignment: .trailing)
                    Text("ACTION")
                        .frame(width: 90, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))

                Divider()

                if filteredFormats.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No matching formats found")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredFormats) { item in
                                FormatRowView(
                                    item: item,
                                    isSelected: selectedFormatId == item.formatId,
                                    onSelect: {
                                        selectedFormatId = item.formatId
                                    },
                                    onDownload: {
                                        selectedFormatId = item.formatId
                                        onSelectAndDownload?(item)
                                    }
                                )
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 260)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }
}

private struct FormatRowView: View {
    let item: FormatItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // Format ID
            Text(item.formatId)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
                )
                .frame(width: 80, alignment: .leading)

            // Stream Type Pill
            HStack(spacing: 4) {
                Image(systemName: item.isAudioOnly ? "waveform" : (item.isMuxedVideoAndAudio ? "film.fill" : "video"))
                    .font(.system(size: 9))
                Text(item.isAudioOnly ? "Audio" : (item.isMuxedVideoAndAudio ? "Muxed" : "Video"))
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(item.isAudioOnly ? .purple : (item.isMuxedVideoAndAudio ? .blue : .orange))
            .frame(width: 100, alignment: .leading)

            // Resolution / Note
            VStack(alignment: .leading, spacing: 2) {
                Text(item.qualityLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                if let fps = item.fps, fps > 0 {
                    Text("\(Int(fps)) fps")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, alignment: .leading)

            // Ext
            Text(item.ext.uppercased())
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            // Codecs
            Text(item.codecSummary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // File Size
            Text(item.formattedSize)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(item.effectiveFilesize != nil ? .primary : .secondary)
                .frame(width: 90, alignment: .trailing)

            // Action Button
            HStack(spacing: 4) {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Download this stream")
            }
            .frame(width: 90, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.1)
                : (isHovered ? Color.primary.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
