import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;

class FileMetadataService {
  // Write label to file metadata
  Future<bool> writeMetadataToFile(String filePath, String label) async {
    try {
      final extension = path.extension(filePath).toLowerCase();

      if (extension == '.xlsx' || extension == '.xls') {
        return await _writeExcelMetadata(filePath, label);
      } else if (extension == '.jpg' ||
          extension == '.jpeg' ||
          extension == '.png') {
        return await _writeImageMetadata(filePath, label);
      } else if (extension == '.pdf') {
        return await _writePdfMetadata(filePath, label);
      } else if (extension == '.docx' || extension == '.doc') {
        return await _writeDocumentMetadata(filePath, label);
      } else {
        // For unsupported file types, create a sidecar file
        return await _writeSidecarFile(filePath, label);
      }
    } catch (e) {
      print('Error writing metadata: $e');
      return false;
    }
  }

  // Read label from file metadata
  Future<String?> readMetadataFromFile(String filePath) async {
    try {
      final extension = path.extension(filePath).toLowerCase();

      if (extension == '.xlsx' || extension == '.xls') {
        return await _readExcelMetadata(filePath);
      } else if (extension == '.jpg' ||
          extension == '.jpeg' ||
          extension == '.png') {
        return await _readImageMetadata(filePath);
      } else if (extension == '.pdf') {
        return await _readPdfMetadata(filePath);
      } else if (extension == '.docx' || extension == '.doc') {
        return await _readDocumentMetadata(filePath);
      } else {
        // For unsupported file types, read from sidecar file
        return await _readSidecarFile(filePath);
      }
    } catch (e) {
      print('Error reading metadata: $e');
      return null;
    }
  }

  // Excel files metadata handling
  Future<bool> _writeExcelMetadata(String filePath, String label) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // Add or update custom property
      // if (!excel.tables.containsKey('_xlnm.CustomDocumentProperties')) {
      //   // Fix: Use the correct way to create a new sheet
      //   excel.sheets['_xlnm.CustomDocumentProperties'] =
      //       Sheet(excel, '_xlnm.CustomDocumentProperties');
      // }

      final sheet = excel.tables['_xlnm.CustomDocumentProperties']!;
      sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
          'DataMindLabel');
      sheet.updateCell(
          CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0), label);

      // Save the file
      final newBytes = excel.encode();
      if (newBytes != null) {
        await File(filePath).writeAsBytes(newBytes);
        return true;
      }
      return false;
    } catch (e) {
      print('Error writing Excel metadata: $e');
      // If we can't modify the Excel file directly, use a sidecar file
      return await _writeSidecarFile(filePath, label);
    }
  }

  Future<String?> _readExcelMetadata(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      // Try to read custom property
      if (excel.tables.containsKey('_xlnm.CustomDocumentProperties')) {
        final sheet = excel.tables['_xlnm.CustomDocumentProperties']!;
        if (sheet.maxRows >= 1 && sheet.maxCols >= 2) {
          final cell = sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
          if (cell.value != null) {
            return cell.value.toString();
          }
        }
      }

      // If not found, try sidecar file
      return await _readSidecarFile(filePath);
    } catch (e) {
      print('Error reading Excel metadata: $e');
      return await _readSidecarFile(filePath);
    }
  }

  // Image files metadata handling
  Future<bool> _writeImageMetadata(String filePath, String label) async {
    try {
      // For now, use sidecar file for images as direct metadata manipulation is complex
      return await _writeSidecarFile(filePath, label);

      // The following code has issues with the image library:
      /*
      // Read the image
      final bytes = await File(filePath).readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return false;

      // Add metadata - this approach doesn't work with the current image library
      // We would need a more specialized EXIF library

      // Save the image with metadata
      final extension = path.extension(filePath).toLowerCase();
      List<int> newBytes;

      if (extension == '.jpg' || extension == '.jpeg') {
        newBytes = img.encodeJpg(image, quality: 100);
      } else if (extension == '.png') {
        newBytes = img.encodePng(image);
      } else {
        return false;
      }

      await File(filePath).writeAsBytes(newBytes);
      return true;
      */
    } catch (e) {
      print('Error writing image metadata: $e');
      return await _writeSidecarFile(filePath, label);
    }
  }

  Future<String?> _readImageMetadata(String filePath) async {
    try {
      // For now, use sidecar file for images
      return await _readSidecarFile(filePath);

      // The following code has issues with the image library:
      /*
      // Read the image
      final bytes = await File(filePath).readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      // Read metadata - this approach doesn't work with the current image library
      // We would need a more specialized EXIF library

      // If not found, try sidecar file
      return await _readSidecarFile(filePath);
      */
    } catch (e) {
      print('Error reading image metadata: $e');
      return await _readSidecarFile(filePath);
    }
  }

  // PDF files metadata handling
  Future<bool> _writePdfMetadata(String filePath, String label) async {
    try {
      // For now, use sidecar file for PDFs as direct metadata manipulation is complex
      return await _writeSidecarFile(filePath, label);

      // The following code has issues with the PDF library:
      /*
      // Create a temporary file for the modified PDF
      final directory = await getTemporaryDirectory();
      final tempPath = '${directory.path}/temp_${path.basename(filePath)}';

      // Read the original PDF
      final originalFile = File(filePath);
      final originalBytes = await originalFile.readAsBytes();

      // Create a new PDF document with metadata
      final pdf = pw.Document();
      pdf.document.info.keywords = 'DataMindLabel:$label';

      // Add the original PDF content
      final pdfDoc = PdfDocument.openData(originalBytes);
      for (var i = 0; i < pdfDoc.pageCount; i++) {
        final page = pdfDoc.getPage(i + 1);
        pdf.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Container(); // Empty container, we're just preserving the original content
          },
          pageFormat: PdfPageFormat(page.width, page.height),
        ));
      }

      // Save the modified PDF to the temporary file
      final newBytes = await pdf.save();
      await File(tempPath).writeAsBytes(newBytes);

      // Replace the original file with the modified one
      await File(tempPath).copy(filePath);
      await File(tempPath).delete();

      return true;
      */
    } catch (e) {
      print('Error writing PDF metadata: $e');
      return await _writeSidecarFile(filePath, label);
    }
  }

  Future<String?> _readPdfMetadata(String filePath) async {
    try {
      // For now, use sidecar file for PDFs
      return await _readSidecarFile(filePath);

      // The following code has issues with the PDF library:
      /*
      // Read the PDF
      final bytes = await File(filePath).readAsBytes();
      final pdfDoc = PdfDocument.openData(bytes);

      // Read metadata
      final keywords = pdfDoc.info.keywords;
      if (keywords != null && keywords.startsWith('DataMindLabel:')) {
        return keywords.substring('DataMindLabel:'.length);
      }

      // If not found, try sidecar file
      return await _readSidecarFile(filePath);
      */
    } catch (e) {
      print('Error reading PDF metadata: $e');
      return await _readSidecarFile(filePath);
    }
  }

  // Document files metadata handling (placeholder - would need a specific library for .docx/.doc)
  Future<bool> _writeDocumentMetadata(String filePath, String label) async {
    // For now, use sidecar file for documents
    return await _writeSidecarFile(filePath, label);
  }

  Future<String?> _readDocumentMetadata(String filePath) async {
    // For now, use sidecar file for documents
    return await _readSidecarFile(filePath);
  }

  // Sidecar file handling (for unsupported file types or as fallback)
  Future<bool> _writeSidecarFile(String filePath, String label) async {
    try {
      final sidecarPath = '$filePath.datamind';
      await File(sidecarPath).writeAsString(label);
      return true;
    } catch (e) {
      print('Error writing sidecar file: $e');
      return false;
    }
  }

  Future<String?> _readSidecarFile(String filePath) async {
    try {
      final sidecarPath = '$filePath.datamind';
      final sidecarFile = File(sidecarPath);
      if (await sidecarFile.exists()) {
        return await sidecarFile.readAsString();
      }
      return null;
    } catch (e) {
      print('Error reading sidecar file: $e');
      return null;
    }
  }

  // Remove metadata from file
  Future<bool> removeMetadataFromFile(String filePath) async {
    try {
      // First try to remove sidecar file (simplest approach)
      final sidecarPath = '$filePath.datamind';
      final sidecarFile = File(sidecarPath);
      if (await sidecarFile.exists()) {
        await sidecarFile.delete();
      }

      // For other file types, we would need to implement specific removal logic
      // This is a simplified version that just removes the sidecar file

      return true;
    } catch (e) {
      print('Error removing metadata: $e');
      return false;
    }
  }
}
