import 'package:flutter/material.dart';

class PerformanceMetricsPanel extends StatelessWidget {
  final Map<String, dynamic> metrics;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const PerformanceMetricsPanel({
    super.key,
    required this.metrics,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Performance Metrics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    tooltip: 'Refresh metrics',
                  ),
              ],
            ),
            const SizedBox(height: 16.0),
            
            // Cache Overview
            if (metrics.containsKey('overallCacheStats')) ...[
              _buildSectionTitle(context, 'Cache Overview'),
              const SizedBox(height: 8.0),
              _buildCacheOverview(context, metrics['overallCacheStats']),
              const SizedBox(height: 16.0),
            ],
            
            // Query Timings
            if (metrics.containsKey('timings') && 
                (metrics['timings'] as Map<String, dynamic>).isNotEmpty) ...[
              _buildSectionTitle(context, 'Query Timings (ms)'),
              const SizedBox(height: 8.0),
              _buildTimingsTable(context, metrics['timings']),
              const SizedBox(height: 16.0),
            ],
            
            // Cache Statistics
            if (metrics.containsKey('cacheStats') && 
                (metrics['cacheStats'] as Map<String, dynamic>).isNotEmpty) ...[
              _buildSectionTitle(context, 'Cache Hit Rates'),
              const SizedBox(height: 8.0),
              _buildCacheStatsTable(context, metrics['cacheStats']),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  Widget _buildCacheOverview(BuildContext context, Map<String, dynamic> stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Articles',
            '${stats['articleCount']}',
            Icons.article,
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: _buildStatCard(
            context,
            'Size',
            '${stats['sizeInMB'].toStringAsFixed(2)} MB',
            Icons.storage,
          ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: _buildStatCard(
            context,
            'Hit Rate',
            '${(stats['hitRate'] * 100).toStringAsFixed(1)}%',
            Icons.speed,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 8.0),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4.0),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimingsTable(BuildContext context, Map<String, dynamic> timings) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16.0,
        columns: const [
          DataColumn(label: Text('Operation')),
          DataColumn(label: Text('Avg'), numeric: true),
          DataColumn(label: Text('Min'), numeric: true),
          DataColumn(label: Text('Max'), numeric: true),
          DataColumn(label: Text('Count'), numeric: true),
        ],
        rows: timings.entries.map((entry) {
          final operation = entry.key;
          final stats = entry.value as Map<String, dynamic>;
          
          return DataRow(
            cells: [
              DataCell(Text(_formatOperationName(operation))),
              DataCell(Text(stats['avg'])),
              DataCell(Text('${stats['min']}')),
              DataCell(Text('${stats['max']}')),
              DataCell(Text('${stats['count']}')),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildCacheStatsTable(BuildContext context, Map<String, dynamic> cacheStats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16.0,
        columns: const [
          DataColumn(label: Text('Operation')),
          DataColumn(label: Text('Hits'), numeric: true),
          DataColumn(label: Text('Misses'), numeric: true),
          DataColumn(label: Text('Hit Rate'), numeric: true),
        ],
        rows: cacheStats.entries.map((entry) {
          final operation = entry.key;
          final stats = entry.value as Map<String, dynamic>;
          
          return DataRow(
            cells: [
              DataCell(Text(_formatOperationName(operation))),
              DataCell(Text('${stats['hits']}')),
              DataCell(Text('${stats['misses']}')),
              DataCell(Text('${stats['hitRate']}')),
            ],
          );
        }).toList(),
      ),
    );
  }
  
  String _formatOperationName(String operation) {
    // Format operation names for better readability
    if (operation.startsWith('getArticle_')) {
      return 'Get Article';
    } else if (operation.startsWith('getArticles_')) {
      return 'List Articles';
    } else if (operation.startsWith('search_')) {
      return 'Search';
    } else if (operation.startsWith('semanticSearch_')) {
      return 'Semantic Search';
    }
    return operation;
  }
} 