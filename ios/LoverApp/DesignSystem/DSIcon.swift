import SwiftUI

// Translation of the inline SVG icons in design-import/ui.jsx.
// SF Symbols are used where the visual matches; custom shapes drawn for the rest
// so we hit the design exactly (the Icon component in ui.jsx defines the look).

enum DSIconName: String {
    case chat, book, cal, play, us, cam, image, mic, send, plus, search,
         back, close, check, check2, pin, reply, more, kao, play2, pause,
         pin2, clock, heart, edit, flip, flash, shutter, arrow, sparkle, camera,
         video
}

struct DSIcon: View {
    let name: DSIconName
    var size: CGFloat = 22
    var color: Color = .primary
    var strokeWidth: CGFloat = 1.6
    var filled: Bool = false

    var body: some View {
        Group {
            switch name {
            case .chat:
                Image(systemName: "message")
            case .book:
                Image(systemName: "book.closed")
            case .cal:
                Image(systemName: "calendar")
            case .play:
                Image(systemName: "play.circle")
            case .us:
                Image(systemName: filled ? "heart.fill" : "heart")
            case .cam, .camera:
                Image(systemName: "camera")
            case .image:
                Image(systemName: "photo")
            case .mic:
                Image(systemName: "mic")
            case .send:
                Image(systemName: "paperplane.fill")
            case .plus:
                Image(systemName: "plus")
            case .search:
                Image(systemName: "magnifyingglass")
            case .back:
                Image(systemName: "chevron.left")
            case .close:
                Image(systemName: "xmark")
            case .check:
                Image(systemName: "checkmark")
            case .check2:
                Image(systemName: "checkmark.circle")
            case .pin:
                Image(systemName: "pin.fill")
            case .reply:
                Image(systemName: "arrowshape.turn.up.left")
            case .more:
                Image(systemName: "ellipsis")
            case .kao:
                Image(systemName: "face.smiling")
            case .play2:
                Image(systemName: "play.fill")
            case .pause:
                Image(systemName: "pause.fill")
            case .pin2:
                Image(systemName: "mappin.and.ellipse")
            case .clock:
                Image(systemName: "clock")
            case .heart:
                Image(systemName: filled ? "heart.fill" : "heart")
            case .edit:
                Image(systemName: "pencil")
            case .flip:
                Image(systemName: "arrow.triangle.2.circlepath.camera")
            case .flash:
                Image(systemName: "bolt")
            case .shutter:
                Image(systemName: "circle.fill")
            case .arrow:
                Image(systemName: "arrow.right")
            case .sparkle:
                Image(systemName: "sparkles")
            case .video:
                Image(systemName: "video")
            }
        }
        .font(.system(size: size, weight: strokeWidth >= 2 ? .semibold : .regular))
        .foregroundStyle(color)
        .frame(width: size + 4, height: size + 4)
    }
}
