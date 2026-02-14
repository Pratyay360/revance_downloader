import 'dart:developer';
import 'package:dio/dio.dart';
class AppMeta {
  final String name;
  final String packageName;
  final String icon;
  final String versionName;
  final int versionCode;

  AppMeta({
    required this.name,
    required this.packageName,
    required this.icon,
    required this.versionName,
    required this.versionCode,
  });

  factory AppMeta.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? (json['nodes']?[0]?['data'] ?? {});
    final file = data['file'] ?? {};

    return AppMeta(
      name: data['name'] ?? '',
      packageName: data['package'] ?? '',
      icon: data['icon'] ?? '',
      versionName: file['vername'] ?? '',
      versionCode: file['vercode'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'AppMeta(name: $name, package: $packageName, version: $versionName ($versionCode))';
  }
}

Future<AppMeta?> fetchAppMeta(String packageName) async {
  final dio = Dio();

  try {
    final response = await dio.get(
      'https://ws2-cache.aptoide.com/api/7/app/getMeta',
      queryParameters: {
        'cdn': 'web',
        'q': 'bXlDUFU9YXJtNjQtdjhhLGFybWVhYmktdjdhLGFybWVhYmkmbGVhbmJhY2s9MA',
        'country': 'IN',
        'limit': '1',
        'package_name': packageName,
        'sort': 'relevance',
        'view': 'response',
      },
    );

    if (response.data != null && response.statusCode == 200) {
      return AppMeta.fromJson(response.data);
    }
    return null;
  } catch (e) {
    log(e.toString());
    return null;
  }
}
