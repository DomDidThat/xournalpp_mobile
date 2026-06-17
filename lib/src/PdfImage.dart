import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:xournalpp/src/PickedFile.dart';
import 'package:xournalpp/src/XppPage.dart';

const double DPI = 96;

Future<int> pdfPageCount(PickedFile pdf) =>
    Printing.raster(pdf.bytes).length;

Future<Uint8List> pdfImage(PickedFile pdf, int? page) async =>
    Printing.raster(pdf.bytes, dpi: 96)
        .toList()
        .then((value) => value[page!].toPng());

Future<XppPageSize> pdfPageSize(PickedFile pdf, int page) async {
  final raster = await Printing.raster(pdf.bytes, dpi: DPI)
      .toList()
      .then((value) => value[page]);
  return XppPageSize(
      width: raster.width.toDouble(), height: raster.height.toDouble());
}
