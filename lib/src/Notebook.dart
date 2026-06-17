import 'dart:typed_data';
import 'package:flutter/material.dart';

class Notebook {
  final String id;
  String title;
  Color coverColor;
  final DateTime createdAt;
  DateTime updatedAt;
  int pageCount;
  Uint8List? xoppData;

  Notebook({
    required this.id,
    required this.title,
    required this.coverColor,
    required this.createdAt,
    required this.updatedAt,
    this.pageCount = 1,
    this.xoppData,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'cover_color': coverColor.toARGB32(),
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'page_count': pageCount,
        'xopp_data': xoppData,
      };

  static Notebook fromMap(Map<String, dynamic> map) => Notebook(
        id: map['id'] as String,
        title: map['title'] as String,
        coverColor: Color(map['cover_color'] as int),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        pageCount: (map['page_count'] as int?) ?? 1,
        xoppData: map['xopp_data'] as Uint8List?,
      );
}
