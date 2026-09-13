import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/config/app_branding.dart';
import '../../core/widgets/merchant_state_view.dart';
import 'products_api_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final ProductsApiService _apiService = ProductsApiService();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];

  bool _isLoading = true;
  String? _error;
  String? _updatingProductId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final results = await Future.wait([
        _apiService.getCategories(),
        _apiService.getProducts(),
      ]);

      if (!mounted) return;

      setState(() {
        _categories = results[0];
        _products = results[1];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    final result = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CategoryFormPage()));

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CategoryFormPage(category: category)),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _addProduct() async {
    if (_categories.isEmpty) {
      final createCategory = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Category required'),
            content: const Text(
              'Create at least one category before adding a product.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Create Category'),
              ),
            ],
          );
        },
      );

      if (createCategory == true) {
        await _createCategory();
      }

      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(categories: _categories),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormPage(categories: _categories, product: product),
      ),
    );

    if (result == true) {
      await _loadData();
    }
  }

  Future<void> _toggleAvailability(
    Map<String, dynamic> product,
    bool value,
  ) async {
    final productId = product['id']?.toString() ?? '';

    if (productId.isEmpty) return;

    try {
      setState(() {
        _updatingProductId = productId;
      });

      await _apiService.updateAvailability(
        productId: productId,
        isAvailable: value,
      );

      if (!mounted) return;

      setState(() {
        product['isAvailable'] = value;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update product: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingProductId = null;
        });
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final productId = product['id']?.toString() ?? '';
    final productName = product['name']?.toString() ?? 'this product';

    if (productId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text('Are you sure you want to delete $productName?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _updatingProductId = productId;
      });

      await _apiService.deleteProduct(productId);

      if (!mounted) return;

      setState(() {
        _products.removeWhere((item) => item['id']?.toString() == productId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete product: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingProductId = null;
        });
      }
    }
  }

  String _categoryName(String categoryId) {
    for (final category in _categories) {
      if (category['id']?.toString() == categoryId) {
        return category['name']?.toString() ?? 'Category';
      }
    }

    return 'Category';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Add Category',
            onPressed: _createCategory,
            icon: const Icon(Icons.category_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _loadData, child: _buildBody()),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const MerchantLoadingView(message: 'Loading products...');
    }

    if (_error != null) {
      return MerchantStateView(
        icon: Icons.error_outline,
        title: 'Unable to load products',
        message: _error,
        actionLabel: 'Retry',
        onAction: _loadData,
      );
    }

    if (_products.isEmpty && _categories.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          const Text(
            'No products yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _categories.isEmpty
                ? 'Create a category and add your first product.'
                : 'Add your first product to start building your menu.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_categories.isEmpty)
            FilledButton.icon(
              onPressed: _createCategory,
              icon: const Icon(Icons.add),
              label: const Text('Create Category'),
            ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCategoriesSection();
        }

        final product = _products[index - 1];

        final productId = product['id']?.toString() ?? '';

        final available = product['isAvailable'] == true;

        final stock = product['stock'] ?? 0;

        final categoryId = product['categoryId']?.toString() ?? '';

        final price = product['price'] ?? 0;

        final imageUrl = product['imageUrl']?.toString() ?? '';

        final isUpdating = _updatingProductId == productId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            onTap: isUpdating
                ? null
                : () {
                    _editProduct(product);
                  },
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 82,
                height: 82,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) {
                          return const Center(
                            child: Icon(Icons.broken_image_outlined, size: 48),
                          );
                        },
                      )
                    : Container(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          Icons.fastfood,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            ),
            title: Text(
              product['name']?.toString() ?? 'Product',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_categoryName(categoryId)} • '
                    '${AppBrandingController.instance.branding.currencySymbol}$price',
                  ),
                  const SizedBox(height: 3),
                  Text('Stock: $stock'),
                  const SizedBox(height: 3),
                  _AvailabilityBadge(available: available),
                ],
              ),
            ),
            trailing: isUpdating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'availability':
                          _toggleAvailability(product, !available);
                          break;

                        case 'edit':
                          _editProduct(product);
                          break;

                        case 'delete':
                          _deleteProduct(product);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'availability',
                        child: Text(
                          available ? 'Mark Unavailable' : 'Mark Available',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit Product'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete Product'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Categories',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final imageUrl = category['imageUrl']?.toString();

              return SizedBox(
                width: 150,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _editCategory(category),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              child: const Icon(
                                                Icons.category_outlined,
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.add_a_photo_outlined,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category['name']?.toString() ?? 'Category',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_products.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 28),
            child: Center(
              child: Text(
                'Add your first product to start building your menu.',
              ),
            ),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? const Color(0xFF16A34A) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        available ? 'Available' : 'Unavailable',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CategoryFormPage extends StatefulWidget {
  const CategoryFormPage({super.key, this.category});

  final Map<String, dynamic>? category;

  @override
  State<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends State<CategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ProductsApiService _apiService = ProductsApiService();
  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _sortOrderController;

  XFile? _selectedImage;
  String? _existingImageUrl;
  bool _isActive = true;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    final category = widget.category;

    _nameController = TextEditingController(
      text: category?['name']?.toString() ?? '',
    );
    _sortOrderController = TextEditingController(
      text: category?['sortOrder']?.toString() ?? '0',
    );

    _existingImageUrl = category?['imageUrl']?.toString();
    if (_existingImageUrl?.isEmpty == true) {
      _existingImageUrl = null;
    }

    _isActive = category?['isActive'] != false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null || !mounted) {
      return;
    }

    setState(() {
      _selectedImage = image;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    try {
      setState(() {
        _isSaving = true;
      });

      if (_isEditing) {
        final categoryId = widget.category!['id'].toString();

        await _apiService.updateCategory(
          categoryId: categoryId,
          name: _nameController.text.trim(),
          sortOrder: sortOrder,
          isActive: _isActive,
        );

        if (_selectedImage != null) {
          final imageUrl = await _apiService.uploadCategoryImage(
            filePath: _selectedImage!.path,
          );

          await _apiService.updateCategoryImage(
            categoryId: categoryId,
            imageUrl: imageUrl,
          );
        }
      } else {
        final category = await _apiService.createCategory(
          name: _nameController.text.trim(),
        );

        final categoryId = category['id']?.toString();

        if (_selectedImage != null &&
            categoryId != null &&
            categoryId.isNotEmpty) {
          final imageUrl = await _apiService.uploadCategoryImage(
            filePath: _selectedImage!.path,
          );

          await _apiService.updateCategoryImage(
            categoryId: categoryId,
            imageUrl: imageUrl,
          );
        }

        if (categoryId != null && categoryId.isNotEmpty && sortOrder != 0) {
          await _apiService.updateCategory(
            categoryId: categoryId,
            name: _nameController.text.trim(),
            sortOrder: sortOrder,
            isActive: true,
          );
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save category: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildImage() {
    Widget child;

    if (_selectedImage != null) {
      child = Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_existingImageUrl != null) {
      child = Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    } else {
      child = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 48),
          SizedBox(height: 8),
          Text('Choose Category Image'),
        ],
      );
    }

    return InkWell(
      onTap: _isSaving ? null : _pickImage,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 190,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImage(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                _selectedImage != null || _existingImageUrl != null
                    ? 'Change Image'
                    : 'Select Image',
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category name is required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sortOrderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Sort Order',
                hintText: '0',
                border: OutlineInputBorder(),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  _isActive ? 'Visible to customers' : 'Hidden from customers',
                ),
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Create Category'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, required this.categories, this.product});

  final List<Map<String, dynamic>> categories;
  final Map<String, dynamic>? product;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  final ProductsApiService _apiService = ProductsApiService();

  final ImagePicker _imagePicker = ImagePicker();

  late final TextEditingController _nameController;

  late final TextEditingController _descriptionController;

  late final TextEditingController _priceController;

  late final TextEditingController _stockController;

  String? _categoryId;

  bool _isSaving = false;

  XFile? _selectedImage;
  String? _existingImageUrl;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _existingImageUrl = product?['imageUrl']?.toString();

    if (_existingImageUrl?.isEmpty == true) {
      _existingImageUrl = null;
    }

    _nameController = TextEditingController(
      text: product?['name']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: product?['description']?.toString() ?? '',
    );

    _priceController = TextEditingController(
      text: product?['price']?.toString() ?? '',
    );

    _stockController = TextEditingController(
      text: product?['stock']?.toString() ?? '0',
    );

    final existingCategoryId = product?['categoryId']?.toString();

    final categoryExists = widget.categories.any(
      (category) => category['id']?.toString() == existingCategoryId,
    );

    if (categoryExists) {
      _categoryId = existingCategoryId;
    } else if (widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();

    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to select image: $error')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoryId == null) {
      return;
    }

    final price = double.tryParse(_priceController.text.trim());

    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || stock == null) {
      return;
    }

    try {
      setState(() {
        _isSaving = true;
      });

      String? imageUrl = _existingImageUrl;

      if (_selectedImage != null) {
        imageUrl = await _apiService.uploadProductImage(
          filePath: _selectedImage!.path,
        );
      }

      if (_isEditing) {
        await _apiService.updateProduct(
          productId: widget.product!['id'].toString(),
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
          price: price,
          stock: stock,
          imageUrl: imageUrl,
        );
      } else {
        await _apiService.createProduct(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          categoryId: _categoryId!,
          price: price,
          stock: stock,
          imageUrl: imageUrl,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save product: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildProductImage() {
    Widget child;

    if (_selectedImage != null) {
      child = Image.file(
        File(_selectedImage!.path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_existingImageUrl != null) {
      child = Image.network(
        _existingImageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          );
        },
      );
    } else {
      child = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 48),
          SizedBox(height: 8),
          Text('Choose Product Image'),
        ],
      );
    }

    return InkWell(
      onTap: _isSaving ? null : _pickImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 190,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildProductImage(),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isSaving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(
                  _selectedImage != null || _existingImageUrl != null
                      ? 'Change Image'
                      : 'Choose Image',
                ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Product name is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: widget.categories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category['id'].toString(),
                      child: Text(category['name']?.toString() ?? 'Category'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Category is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Price',
                prefixText:
                    '${AppBrandingController.instance.branding.currencySymbol} ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final price = double.tryParse(value?.trim() ?? '');

                if (price == null || price < 0) {
                  return 'Enter a valid price';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Stock',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final stock = int.tryParse(value?.trim() ?? '');

                if (stock == null || stock < 0) {
                  return 'Enter valid stock';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Update Product' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }
}
