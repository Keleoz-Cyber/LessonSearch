import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/providers.dart';

class RankingService {
  final ApiClient _api;

  RankingService(this._api);

  Future<Map<String, dynamic>> getRankingList({
    String periodType = '7d',
    String rankType = 'score',
  }) async {
    final response = await _api.dio.get(
      '/ranking/list',
      queryParameters: {'period_type': periodType, 'rank_type': rankType},
    );
    return response.data as Map<String, dynamic>;
  }
}

final rankingServiceProvider = Provider<RankingService>((ref) {
  return RankingService(ref.read(apiClientProvider));
});

final rankingListProvider =
    FutureProvider.family<Map<String, dynamic>, ({String period, String type})>(
      (ref, params) {
        return ref
            .read(rankingServiceProvider)
            .getRankingList(periodType: params.period, rankType: params.type);
      },
    );
