import SwiftUI

/// A tiny pixel-art bitmap: one character per pixel, `.` for transparent.
/// Uppercase letters are fixed palette colors; lowercase letters are body
/// colors that follow the worn color item.
struct PixelBitmap {
  let rows: [String]
  /// Column and row of the bitmap's top-left corner on the 24×24 sprite grid.
  let origin: (x: Int, y: Int)

  init(x: Int, y: Int, _ rows: [String]) {
    self.origin = (x, y)
    self.rows = rows
  }

  var width: Int { rows.map(\.count).max() ?? 0 }
  var height: Int { rows.count }
}

/// Body colors for one color item.
struct CompanionPalette {
  let body: Color
  let dark: Color
  let light: Color
  let blush: Color
  let eye: Color

  init(body: UInt32, dark: UInt32, light: UInt32, blush: UInt32 = 0xFF8FB2, eye: UInt32 = 0x1B2A52)
  {
    self.body = Color(hex: body)
    self.dark = Color(hex: dark)
    self.light = Color(hex: light)
    self.blush = Color(hex: blush)
    self.eye = Color(hex: eye)
  }

  static let aqua = CompanionPalette(body: 0x3D8BFF, dark: 0x1F5FD0, light: 0x9ECBFF)

  static func palette(for colorItemID: String?) -> CompanionPalette {
    switch colorItemID {
    case "colorLeaf": return CompanionPalette(body: 0x5CC46A, dark: 0x2F8F3F, light: 0xB5F0B8)
    case "colorSakura":
      return CompanionPalette(body: 0xF7A1C4, dark: 0xD8699A, light: 0xFFD6E6, blush: 0xFF5C8A)
    case "colorLavender": return CompanionPalette(body: 0xA78BFA, dark: 0x7152D6, light: 0xD9CCFF)
    case "colorSunset": return CompanionPalette(body: 0xFF9A4D, dark: 0xD9641A, light: 0xFFD1A6)
    case "colorRuby":
      return CompanionPalette(body: 0xEF4E63, dark: 0xB4203A, light: 0xFFB3BF, blush: 0xFF8FB2)
    case "colorMidnight":
      return CompanionPalette(body: 0x3A4166, dark: 0x1D2140, light: 0x7F88B8, eye: 0xF4F6FF)
    case "colorSnow": return CompanionPalette(body: 0xF1F3F8, dark: 0xB9C0D0, light: 0xFFFFFF)
    case "colorGold": return CompanionPalette(body: 0xF5C542, dark: 0xC48A0A, light: 0xFFF0B3)
    default: return .aqua
    }
  }
}

extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// The slime and every accessory, as bitmaps on a 24×24 grid. The body sits
/// at columns 4–19, rows 10–21; hats hang above it, held items to its left.
enum CompanionArt {
  static let gridSize = 24

  static let body = PixelBitmap(
    x: 4, y: 10,
    [
      "......dddd......",
      "....ddbbbbdd....",
      "...dbbbbbbbbd...",
      "..dbllbbbbbbbd..",
      "..dblbbbbbbbbd..",
      ".dbbbbbbbbbbbbd.",
      ".dbbbewbbbbewbd.",
      ".dbbbeebbbbeebd.",
      ".dbhbbbbmmbbbhd.",
      ".dbbbbbbbbbbbbd.",
      "..dbbbbbbbbbbd..",
      "...dddddddddd...",
    ])

  /// Rows 6–7 of the body with the eyes shut.
  static let blinkRows = [
    ".dbbbbbbbbbbbbd.",
    ".dbbbeebbbbeebd.",
  ]

  /// Rows 8–9 of the body with the mouth open (recording).
  static let listeningRows = [
    ".dbhbbbmmmbbbhd.",
    ".dbbbbbbmmbbbbd.",
  ]

  static func accessory(for itemID: String) -> PixelBitmap? {
    accessories[itemID]
  }

  private static let accessories: [String: PixelBitmap] = [
    // MARK: Hats
    "partyHat": PixelBitmap(
      x: 8, y: 4,
      [
        "...Y...",
        "..YYY..",
        "...P...",
        "..PWP..",
        "..PPP..",
        ".PWPPP.",
        ".PPPPP.",
        "PPPPWPP",
      ]),
    "beanie": PixelBitmap(
      x: 6, y: 5,
      [
        ".....RR.....",
        "....RRRR....",
        "...RRRRRR...",
        "..RRRRRRRR..",
        ".RRRRRRRRRR.",
        "RRRRRRRRRRRR",
        "RWRWRWRWRWRW",
      ]),
    "cowboyHat": PixelBitmap(
      x: 4, y: 6,
      [
        "......NNNN......",
        ".....NNNNNN.....",
        ".....NNNNNN.....",
        ".....NKKKKN.....",
        "NNNNNNNNNNNNNNNN",
        ".NNNNNNNNNNNNNN.",
      ]),
    "headphones": PixelBitmap(
      x: 4, y: 8,
      [
        ".....KKKKKK.....",
        "...KK......KK...",
        "..K..........K..",
        ".K............K.",
        ".K............K.",
        "PP............PP",
        "PP............PP",
        "PP............PP",
      ]),
    "flameBand": PixelBitmap(
      x: 6, y: 9,
      [
        "..Y...Y...Y.",
        ".OYO.OYO.OYO",
        "OOOOOOOOOOOO",
        "RRRRRRRRRRRR",
        ".RRRRRRRRRR.",
      ]),
    "nightcap": PixelBitmap(
      x: 5, y: 3,
      [
        "..........WW..",
        ".........VVWW.",
        "........VVV...",
        ".......VVVV...",
        "......VVVVV...",
        ".....VVVVVV...",
        "....VVVVVVV...",
        "..VVVVVVVVVV..",
        ".WWWWWWWWWWWW.",
      ]),
    "chefHat": PixelBitmap(
      x: 7, y: 3,
      [
        "..WWWWWW..",
        ".WWWWWWWW.",
        ".WWWWWWWW.",
        ".WWWWWWWW.",
        "..WWWWWW..",
        "..WWWWWW..",
        "..WWWWWW..",
        "..SSSSSS..",
        "..WWWWWW..",
      ]),
    "strawHat": PixelBitmap(
      x: 3, y: 7,
      [
        "......YYYYYY......",
        ".....YYYYYYYY.....",
        ".....RRRRRRRR.....",
        "YYYYYYYYYYYYYYYYYY",
        ".YYYYYYYYYYYYYYYY.",
      ]),
    "hardHat": PixelBitmap(
      x: 6, y: 5,
      [
        ".....YY.....",
        "...YYYYYY...",
        "..YYYYYYYY..",
        ".YYYYYYYYYY.",
        ".YYYYYYYYYY.",
        ".YYYYYYYYYY.",
        "OOOOOOOOOOOO",
      ]),
    "wizardHat": PixelBitmap(
      x: 5, y: 1,
      [
        "........U.....",
        ".......UU.....",
        "......UUU.....",
        "......UUYU....",
        ".....UUUUU....",
        "....UUUUUU....",
        "....UUYUUUU...",
        "...UUUUUUUU...",
        "...UUUUUUYU...",
        "..UUUUUUUUUU..",
        "UUUUUUUUUUUUUU",
      ]),
    "graduationCap": PixelBitmap(
      x: 4, y: 7,
      [
        "KKKKKKKKKKKKKKKK",
        ".KKKKKKKKKKKKKK.",
        "....KKKKKKKK.Y..",
        "....KKKKKKKK.Y..",
        "....KKKKKKKK.YY.",
      ]),
    "halo": PixelBitmap(
      x: 6, y: 4,
      [
        "..CCCCCCCC..",
        ".CWWWWWWWWC.",
        "..CCCCCCCC..",
      ]),
    "topHat": PixelBitmap(
      x: 6, y: 3,
      [
        "..KKKKKKKK..",
        "..KKKKKKKK..",
        "..KKKKKKKK..",
        "..KKKKKKKK..",
        "..KKKKKKKK..",
        "..RRRRRRRR..",
        "..KKKKKKKK..",
        "KKKKKKKKKKKK",
        "KKKKKKKKKKKK",
      ]),
    "crown": PixelBitmap(
      x: 7, y: 5,
      [
        "Y...YY...Y",
        "YY..YY..YY",
        "YYY.YY.YYY",
        "YYYYYYYYYY",
        "YRYYYRYYRY",
        "YYYYYYYYYY",
        "YYYYYYYYYY",
      ]),

    // MARK: Face (eyes are at columns 8–9 and 15–16, rows 16–17)
    "glasses": PixelBitmap(
      x: 7, y: 15,
      [
        "KKKK...KKKK",
        "K..KKKKK..K",
        "K..K...K..K",
        "KKKK...KKKK",
      ]),
    "sunglasses": PixelBitmap(
      x: 7, y: 15,
      [
        "KKKKKKKKKKK",
        "KKKK...KKKK",
        "KKKK...KKKK",
      ]),
    "monocle": PixelBitmap(
      x: 14, y: 15,
      [
        "KKKK.",
        "K..K.",
        "K..K.",
        "KKKK.",
        "...Y.",
        "....Y",
      ]),
    "eyepatch": PixelBitmap(
      x: 7, y: 15,
      [
        "KKKKKKKKKKK",
        "KKKK.......",
        "KKKK.......",
        "KKKK.......",
      ]),
    "mustache": PixelBitmap(
      x: 8, y: 18,
      [
        "NNN...NNN",
        ".NN...NN.",
      ]),
    "mask": PixelBitmap(
      x: 6, y: 18,
      [
        "WWWWWWWWWWWW",
        "WWWWWWWWWWWW",
        ".WWWWWWWWWW.",
      ]),
    "starEyes": PixelBitmap(
      x: 8, y: 15,
      [
        ".Y.....Y.",
        "YYY...YYY",
        "YYY...YYY",
        ".Y.....Y.",
      ]),

    // MARK: Held (to the left of the body, which starts at column 5)
    "microphone": PixelBitmap(
      x: 1, y: 13,
      [
        ".III.",
        "IIIII",
        "IIIII",
        ".III.",
        "..K..",
        "..K..",
        "..K..",
        ".KKK.",
      ]),
    "pencil": PixelBitmap(
      x: 1, y: 13,
      [
        "..P..",
        "..Y..",
        "..Y..",
        "..Y..",
        "..Y..",
        "..Y..",
        "..A..",
        "..K..",
      ]),
    "coffee": PixelBitmap(
      x: 1, y: 15,
      [
        "NNNN.",
        "WWWWW",
        "WWWWW",
        "WWWW.",
        ".WWW.",
      ]),
    "flag": PixelBitmap(
      x: 1, y: 12,
      [
        "KRRRR",
        "KRRRR",
        "KRRR.",
        "K....",
        "K....",
        "K....",
        "K....",
        "K....",
      ]),
    "book": PixelBitmap(
      x: 1, y: 15,
      [
        "VVVVV",
        "VWWWV",
        "VWWWV",
        "VWWWV",
        "VWWWV",
        "VVVVV",
      ]),
    "umbrella": PixelBitmap(
      x: 1, y: 12,
      [
        "..R..",
        ".RRR.",
        "RWRWR",
        "RRRRR",
        "..K..",
        "..K..",
        "..K..",
        ".KK..",
      ]),
    "wand": PixelBitmap(
      x: 1, y: 12,
      [
        "..Y..",
        ".YYY.",
        "YYYYY",
        ".YYY.",
        "..A..",
        "..A..",
        "..A..",
        "..A..",
      ]),
    "trophy": PixelBitmap(
      x: 1, y: 14,
      [
        "YYYYY",
        "YYYYY",
        ".YYY.",
        "..Y..",
        ".YYY.",
        "YYYYY",
      ]),
  ]

  static func fixedColor(_ character: Character) -> Color? {
    switch character {
    case "K": return Color(hex: 0x1E1F2B)
    case "W": return Color(hex: 0xFFFFFF)
    case "Y": return Color(hex: 0xF7C948)
    case "R": return Color(hex: 0xE5484D)
    case "O": return Color(hex: 0xF28C28)
    case "G": return Color(hex: 0x4CAF50)
    case "P": return Color(hex: 0xF48FB1)
    case "U": return Color(hex: 0x7E57C2)
    case "N": return Color(hex: 0x9C6B3C)
    case "C": return Color(hex: 0x8FD3FF)
    case "S": return Color(hex: 0x9AA0AD)
    case "A": return Color(hex: 0xD9B48F)
    case "I": return Color(hex: 0xCFD6E4)
    case "V": return Color(hex: 0x2B3A67)
    default: return nil
    }
  }

  static func color(_ character: Character, palette: CompanionPalette) -> Color? {
    switch character {
    case ".": return nil
    case "b": return palette.body
    case "d": return palette.dark
    case "l": return palette.light
    case "h": return palette.blush
    case "e", "m": return palette.eye
    case "w": return Color(hex: 0xFFFFFF)
    default: return fixedColor(character)
    }
  }
}

/// Draws the companion — body plus whatever it wears — crisp at any size.
struct CompanionSpriteView: View {
  var outfit: CompanionOutfit
  /// Open the mouth while a recording is in progress.
  var listening = false
  /// Bob and blink on a slow timer; off for thumbnails.
  var animated = true
  var size: CGFloat = 96

  var body: some View {
    if animated {
      TimelineView(.periodic(from: .now, by: 0.55)) { context in
        let frame = Int(context.date.timeIntervalSinceReferenceDate / 0.55)
        canvas(frame: frame)
      }
    } else {
      canvas(frame: 0)
    }
  }

  private func canvas(frame: Int) -> some View {
    let bob = frame % 2 == 1 ? 1 : 0
    let blink = frame % 9 == 7 && !listening
    return Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) {
      context, canvasSize in
      let pixel = canvasSize.width / CGFloat(CompanionArt.gridSize)
      let palette = CompanionPalette.palette(for: outfit.color)

      func draw(_ bitmap: PixelBitmap, rowOverrides: [Int: String] = [:]) {
        for (rowIndex, rowString) in bitmap.rows.enumerated() {
          let row = rowOverrides[rowIndex] ?? rowString
          for (columnIndex, character) in row.enumerated() {
            guard let color = CompanionArt.color(character, palette: palette) else { continue }
            let rect = CGRect(
              x: CGFloat(bitmap.origin.x + columnIndex) * pixel,
              y: CGFloat(bitmap.origin.y + rowIndex + bob) * pixel,
              width: pixel, height: pixel)
            // Slight overdraw so no hairline gaps show between pixels.
            context.fill(Path(rect.insetBy(dx: -0.25, dy: -0.25)), with: .color(color))
          }
        }
      }

      var overrides: [Int: String] = [:]
      if blink {
        overrides[6] = CompanionArt.blinkRows[0]
        overrides[7] = CompanionArt.blinkRows[1]
      }
      if listening {
        overrides[8] = CompanionArt.listeningRows[0]
        overrides[9] = CompanionArt.listeningRows[1]
      }
      draw(CompanionArt.body, rowOverrides: overrides)

      for category in [CompanionItemCategory.held, .face, .hat] {
        guard let id = outfit.itemID(for: category),
          let bitmap = CompanionArt.accessory(for: id)
        else { continue }
        draw(bitmap)
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

/// A single item on its own, scaled to fill a thumbnail. Color items show
/// the bare body in that color.
struct CompanionItemThumbnail: View {
  let item: CompanionItem
  var size: CGFloat = 56

  var body: some View {
    Canvas(opaque: false, colorMode: .nonLinear, rendersAsynchronously: false) {
      context, canvasSize in
      let bitmap: PixelBitmap
      let palette: CompanionPalette
      if item.category == .color {
        bitmap = CompanionArt.body
        palette = CompanionPalette.palette(for: item.id)
      } else {
        guard let accessory = CompanionArt.accessory(for: item.id) else { return }
        bitmap = accessory
        palette = .aqua
      }
      let columns = max(bitmap.width, 1)
      let rows = max(bitmap.height, 1)
      let pixel = min(canvasSize.width / CGFloat(columns), canvasSize.height / CGFloat(rows))
      let offsetX = (canvasSize.width - CGFloat(columns) * pixel) / 2
      let offsetY = (canvasSize.height - CGFloat(rows) * pixel) / 2
      for (rowIndex, row) in bitmap.rows.enumerated() {
        for (columnIndex, character) in row.enumerated() {
          guard let color = CompanionArt.color(character, palette: palette) else { continue }
          let rect = CGRect(
            x: offsetX + CGFloat(columnIndex) * pixel,
            y: offsetY + CGFloat(rowIndex) * pixel,
            width: pixel, height: pixel)
          context.fill(Path(rect.insetBy(dx: -0.25, dy: -0.25)), with: .color(color))
        }
      }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}
