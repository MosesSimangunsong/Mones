import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../core/errors/app_exception.dart';
import '../import/ocr_text_assembler.dart';

/// Membaca teks dari gambar. Dipisah sebagai antarmuka agar bisa diganti pada
/// pengujian.
abstract class ImageTextRecognizer {
  Future<String> recognize(String imagePath);
}

/// OCR di perangkat memakai Google ML Kit (offline, gambar tidak dikirim ke
/// server mana pun).
class MlKitImageTextRecognizer implements ImageTextRecognizer {
  const MlKitImageTextRecognizer();

  @override
  Future<String> recognize(String imagePath) async {
    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final RecognizedText result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final List<OcrLine> lines = <OcrLine>[
        for (final TextBlock block in result.blocks)
          for (final TextLine line in block.lines)
            OcrLine(
              text: line.text,
              left: line.boundingBox.left,
              top: line.boundingBox.top,
              height: line.boundingBox.height,
            ),
      ];
      return OcrTextAssembler.assemble(lines);
    } catch (_) {
      throw AppException('Teks pada gambar tidak bisa dibaca.');
    } finally {
      await recognizer.close();
    }
  }
}
