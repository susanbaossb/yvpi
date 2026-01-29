import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildHolidayCard(context)),
        const SizedBox(width: 16),
        Expanded(child: _LivenessCard()),
        const SizedBox(width: 16),
        Expanded(child: _RewardCard()),
      ],
    );
  }

  Widget _buildHolidayCard(BuildContext context) {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Mon, 7 = Sun
    String title = '今天提桶!';
    String subtitle = '明天跑路!';
    String status = '周六加载中...';
    String highlight = '明天放假';
    IconData icon = Icons.celebration;

    // Simple logic
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      title = '今天是周末';
      subtitle = '好好休息';
      status = '享受生活';
      highlight = '周末愉快';
      icon = Icons.weekend;
    } else if (weekday == DateTime.friday) {
      title = '今天周五';
      subtitle = '即将解放';
      status = '周六加载 99%';
      highlight = '明天放假';
    } else {
      int daysLeft = 6 - weekday; // Sat is 6. If Mon(1), 5 days left.
      title = '今天搬砖';
      subtitle = '为了生活';
      status = '距离周末还有 $daysLeft 天';
      highlight = '加油呀';
      icon = Icons.work_history;
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  status,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.green, size: 24),
                Text(
                  highlight,
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LivenessCard extends StatefulWidget {
  @override
  State<_LivenessCard> createState() => _LivenessCardState();
}

class _LivenessCardState extends State<_LivenessCard> {
  int _liveness = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchLiveness();
  }

  Future<void> _fetchLiveness() async {
    try {
      final api = context.read<AuthProvider>().api;
      final liveness = await api.getLiveness();
      if (mounted) {
        setState(() {
          _liveness = liveness;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Text(
                  '今日未签到',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.cyan.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '今日活跃进度',
                    style: TextStyle(fontSize: 10, color: Colors.cyan),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_liveness / 100.0).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[200],
                    color: Colors.cyan,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_liveness%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '今日活跃度到达 10% 后\n系统将自动签到',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatefulWidget {
  @override
  State<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends State<_RewardCard> {
  bool _claiming = false;

  Future<void> _claim() async {
    if (_claiming) return;
    setState(() => _claiming = true);
    try {
      final api = context.read<AuthProvider>().api;
      final msg = await api.collectYesterdayReward();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x11000000)),
      ),
      child: InkWell(
        onTap: _claim,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: Colors.orange, size: 32),
              const SizedBox(height: 8),
              const Text(
                '昨日活跃奖励',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _claiming ? '领取中...' : '一键领取 · 活跃积分',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
