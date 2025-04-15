import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  Future<List<String>> extractIngredients(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(
      inputImage,
    );
    await textRecognizer.close();

    final rawText = recognizedText.text;
    final ingredients =
        rawText
            .split(RegExp(r'[,|\n]')) // split by comma or new line
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return ingredients;
  }
}
