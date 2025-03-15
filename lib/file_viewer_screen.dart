import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'file_model.dart';

class FileViewerScreen extends StatelessWidget {
  final FileModel file;

  const FileViewerScreen({Key? key, required this.file}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(file.name),
      ),
      body: _buildFileViewer(),
    );
  }

  Widget _buildFileViewer() {
    if (file.type == 'pdf') {
      return PDFView(
        filePath: file.path,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        defaultPage: 0,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        onRender: (_pages) {
          // PDF is rendered
        },
        onError: (error) {
          print('Error rendering PDF: $error');
        },
        onPageError: (page, error) {
          print('Error on page $page: $error');
        },
        onViewCreated: (PDFViewController pdfViewController) {
          // PDF view created
        },
        onPageChanged: (int? page, int? total) {
          print('Page changed: $page/$total');
        },
      );
    } else if (file.type == 'image') {
      return Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            File(file.path),
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      return const Center(
        child: Text('This file type cannot be previewed directly'),
      );
    }
  }
}
