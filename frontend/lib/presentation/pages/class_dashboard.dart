import 'package:adark_frontend/views/widgets/stat_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ClassDashboard extends StatefulWidget {
  const ClassDashboard({super.key});
  @override
  State<ClassDashboard> createState() => _ClassDashboardState();
}

class _ClassDashboardState extends State<ClassDashboard> {
  static const List<String> _filters = [
    'Hôm nay',
    'Tuần này',
    'Tháng này',
    'Tùy chọn'
  ];
  final ValueNotifier<int> _selectedFilter = ValueNotifier(0);

  @override
  void dispose() {
    _selectedFilter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterBar(),
          _buildStatGrid(),
          Text(
            'Biểu đồ báo cáo hàng ngày',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          _buildTrendChart(context),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return ValueListenableBuilder<int>(
        valueListenable: _selectedFilter,
        builder: (context, selected, _) {
          return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _filters.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_filters[i]),
                        selected: selected == i,
                        showCheckmark: false,
                        onSelected: (_) => _selectedFilter.value = i,
                      ),
                    )
                ],
              ));
        });
  }

  Widget _buildStatGrid() {
    return GridView.count(
      crossAxisCount: 2, // 2 cột → thành 2 hàng × 2
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // không tự cuộn
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        StatCard(
            label: 'Tổng trẻ',
            value: '248',
            icon: Icons.child_care,
            color: Colors.blue),
        StatCard(
          label: 'Đã gửi',
          value: '186',
          icon: Icons.check_circle,
          color: Colors.green,
          suffix: '75%',
        ),
        StatCard(
            label: 'Chờ',
            value: '47',
            suffix: '19%',
            icon: Icons.hourglass_top,
            color: Colors.orange),
        StatCard(
            label: 'Lỗi',
            value: '15',
            suffix: '6%',
            icon: Icons.error,
            color: Colors.red),
      ],
    );
  }

  Widget _buildTrendChart(BuildContext context) {
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    const values = [32, 41, 28, 55, 38, 24, 12];
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: [
            for (int i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  color: Colors.teal,
                  borderRadius: BorderRadius.circular(4),
                  width: 18,
                )
              ])
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => Text(days[value.toInt()]),
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
