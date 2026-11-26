import 'package:adark_frontend/core/errors/app_exception.dart';
import 'package:adark_frontend/core/network/api_client.dart';
import 'package:adark_frontend/core/utils/error_helper.dart';
import 'package:adark_frontend/data/repositories/http_dashboard_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mô phỏng tên class bị mã hóa khi build release với `--obfuscate`.
class _ObfuscatedCustomError implements AppException {
  const _ObfuscatedCustomError(this.message, {this.statusCode});

  @override
  final String message;

  @override
  final int? statusCode;

  @override
  String? get userMessage => null;
}

void main() {
  group('P2 Architecture — ApiClient & AppException', () {
    test('ApiClient.resolveDio tái sử dụng chung 1 singleton Dio mặc định', () {
      final d1 = ApiClient.resolveDio();
      final d2 = ApiClient.resolveDio();
      expect(identical(d1, d2), isTrue);
    });

    test('HttpDashboardRepository không gắn trùng interceptor lên cùng 1 Dio',
        () {
      final customDio = Dio(BaseOptions(baseUrl: 'http://test.local'));
      final initialCount = customDio.interceptors.length;
      HttpDashboardRepository(dio: customDio);
      HttpDashboardRepository(dio: customDio);

      expect(customDio.interceptors.length, initialCount + 1);
    });

    test('getFriendlyErrorMessage hoạt động với AppException bất kể tên class',
        () {
      const err = _ObfuscatedCustomError('Lớp học đã đạt sĩ số tối đa');
      expect(getFriendlyErrorMessage(err), 'Lớp học đã đạt sĩ số tối đa');

      const conflict = _ObfuscatedCustomError('Conflict', statusCode: 409);
      expect(
        getFriendlyErrorMessage(conflict),
        contains('đã được sử dụng'),
      );
    });
  });
}
