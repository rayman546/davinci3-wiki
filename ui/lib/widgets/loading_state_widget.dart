import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Type of loading state
enum LoadingType {
  /// Initial loading (first data fetch)
  initial,
  
  /// Loading more items (pagination)
  pagination,
  
  /// Refreshing existing content
  refresh,
  
  /// Small inline loading indicator
  inline,
}

/// A reusable widget for displaying consistent loading states across the app.
/// 
/// Features:
/// - Support for different loading types (initial, pagination, refresh)
/// - Skeleton loading capability for better UX
/// - Customizable appearance and messages
class LoadingStateWidget extends StatelessWidget {
  /// The type of loading state
  final LoadingType loadingType;
  
  /// Optional message to display during loading
  final String? message;
  
  /// Whether to show skeleton loading instead of spinner
  final bool useSkeleton;
  
  /// The type of content being loaded (affects skeleton appearance)
  final SkeletonType skeletonType;
  
  /// Number of skeleton items to show
  final int skeletonItemCount;
  
  /// Whether the skeleton should take the full screen height
  final bool fullHeight;
  
  /// Custom widget to display instead of default loading indicators
  final Widget? customLoadingWidget;

  const LoadingStateWidget({
    Key? key,
    this.loadingType = LoadingType.initial,
    this.message,
    this.useSkeleton = false,
    this.skeletonType = SkeletonType.article,
    this.skeletonItemCount = 3,
    this.fullHeight = false,
    this.customLoadingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use custom widget if provided
    if (customLoadingWidget != null) {
      return customLoadingWidget!;
    }
    
    // Choose appropriate loading indicator based on type
    switch (loadingType) {
      case LoadingType.initial:
        if (useSkeleton) {
          return _buildSkeletonLoading(context);
        } else {
          return _buildInitialLoading(context);
        }
      case LoadingType.pagination:
        return _buildPaginationLoading(context);
      case LoadingType.refresh:
        return _buildRefreshLoading(context);
      case LoadingType.inline:
        return _buildInlineLoading(context);
    }
  }
  
  Widget _buildInitialLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPaginationLoading(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(strokeWidth: 3),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildRefreshLoading(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            if (message != null) ...[
              const SizedBox(width: 8),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInlineLoading(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        if (message != null) ...[
          const SizedBox(width: 8),
          Text(
            message!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
  
  Widget _buildSkeletonLoading(BuildContext context) {
    Widget skeletonItem;
    
    // Choose skeleton based on content type
    switch (skeletonType) {
      case SkeletonType.article:
        skeletonItem = _buildArticleSkeleton(context);
        break;
      case SkeletonType.searchResult:
        skeletonItem = _buildSearchResultSkeleton(context);
        break;
      case SkeletonType.articleDetail:
        skeletonItem = _buildArticleDetailSkeleton(context);
        break;
      case SkeletonType.settings:
        skeletonItem = _buildSettingsSkeleton(context);
        break;
    }
    
    // Build list of skeleton items or single item
    if (skeletonType == SkeletonType.articleDetail) {
      return skeletonItem; // Article detail is a single full-page skeleton
    } else {
      return ListView.builder(
        itemCount: skeletonItemCount,
        shrinkWrap: !fullHeight,
        physics: fullHeight ? null : const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: skeletonItem,
        ),
      );
    }
  }
  
  Widget _buildShimmerEffect(Widget child) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: child,
    );
  }
  
  Widget _buildArticleSkeleton(BuildContext context) {
    return _buildShimmerEffect(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Container(
                width: double.infinity,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              // Summary
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity * 0.7,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              // Metadata
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSearchResultSkeleton(BuildContext context) {
    return _buildShimmerEffect(
      ListTile(
        title: Container(
          width: double.infinity,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity * 0.8,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildArticleDetailSkeleton(BuildContext context) {
    return _buildShimmerEffect(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Container(
              width: double.infinity,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 24),
            // Summary
            Container(
              width: double.infinity,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity * 0.7,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            // Content paragraphs
            for (int i = 0; i < 6; i++) ...[
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity * 0.8,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSettingsSkeleton(BuildContext context) {
    return _buildShimmerEffect(
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section title
              Container(
                width: 120,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Settings items
              for (int i = 0; i < 3; i++) ...[
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 160,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Type of skeleton loading to display
enum SkeletonType {
  /// Article card skeleton
  article,
  
  /// Search result skeleton
  searchResult,
  
  /// Article detail page skeleton
  articleDetail,
  
  /// Settings item skeleton
  settings,
} 