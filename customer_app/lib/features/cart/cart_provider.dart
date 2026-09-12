import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.availableStock,
  });

  final String id;
  final String name;
  final int price;
  final int quantity;

  /// Latest stock known by the customer app.
  ///
  /// This is only for UX validation.
  /// Backend remains the final authority.
  final int availableStock;

  CartItem copyWith({int? quantity, int? availableStock}) {
    return CartItem(
      id: id,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      availableStock: availableStock ?? this.availableStock,
    );
  }
}

class CartState {
  const CartState({
    this.storeId,
    this.storeName,
    this.storeAddress,
    this.items = const [],
  });

  final String? storeId;
  final String? storeName;
  final String? storeAddress;
  final List<CartItem> items;

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    String? storeId,
    String? storeName,
    String? storeAddress,
    List<CartItem>? items,
  }) {
    return CartState(
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      items: items ?? this.items,
    );
  }
}

enum AddToCartResult { added, differentStore, outOfStock, maxStockReached }

enum IncreaseQuantityResult { increased, itemNotFound, maxStockReached }

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return const CartState();
  }

  AddToCartResult addItem({
    required String storeId,
    required String storeName,
    required String storeAddress,
    required String id,
    required String name,
    required int price,
    required int availableStock,
  }) {
    if (availableStock <= 0) {
      return AddToCartResult.outOfStock;
    }

    if (state.items.isNotEmpty &&
        state.storeId != null &&
        state.storeId != storeId) {
      return AddToCartResult.differentStore;
    }

    final index = state.items.indexWhere((item) => item.id == id);

    if (index == -1) {
      state = CartState(
        storeId: storeId,
        storeName: storeName,
        storeAddress: storeAddress,
        items: [
          ...state.items,
          CartItem(
            id: id,
            name: name,
            price: price,
            quantity: 1,
            availableStock: availableStock,
          ),
        ],
      );

      return AddToCartResult.added;
    }

    final existingItem = state.items[index];

    if (existingItem.quantity >= availableStock) {
      return AddToCartResult.maxStockReached;
    }

    final items = [...state.items];

    items[index] = existingItem.copyWith(
      quantity: existingItem.quantity + 1,

      // Refresh stock with latest value
      // supplied from product page.
      availableStock: availableStock,
    );

    state = state.copyWith(items: items);

    return AddToCartResult.added;
  }

  IncreaseQuantityResult increaseQuantity(String id) {
    final index = state.items.indexWhere((item) => item.id == id);

    if (index == -1) {
      return IncreaseQuantityResult.itemNotFound;
    }

    final item = state.items[index];

    if (item.quantity >= item.availableStock) {
      return IncreaseQuantityResult.maxStockReached;
    }

    final items = [...state.items];

    items[index] = item.copyWith(quantity: item.quantity + 1);

    state = state.copyWith(items: items);

    return IncreaseQuantityResult.increased;
  }

  void decreaseQuantity(String id) {
    final index = state.items.indexWhere((item) => item.id == id);

    if (index == -1) return;

    final item = state.items[index];

    if (item.quantity <= 1) {
      removeItem(id);
      return;
    }

    final items = [...state.items];

    items[index] = item.copyWith(quantity: item.quantity - 1);

    state = state.copyWith(items: items);
  }

  void removeItem(String id) {
    final items = state.items.where((item) => item.id != id).toList();

    if (items.isEmpty) {
      clearCart();
      return;
    }

    state = state.copyWith(items: items);
  }

  void clearCart() {
    state = const CartState();
  }

  int get subtotal {
    return state.items.fold(
      0,
      (total, item) => total + (item.price * item.quantity),
    );
  }

  int get deliveryFee {
    if (state.items.isEmpty) {
      return 0;
    }

    return 40;
  }

  int get total {
    return subtotal + deliveryFee;
  }

  int get itemCount {
    return state.items.fold(0, (total, item) => total + item.quantity);
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);
