import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { ProductsService } from './products.service.js';

@Controller()
export class ProductsController {
  constructor(
    private readonly productsService: ProductsService,
  ) {}

  // MERCHANT

  @Post('merchant/products')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  async createProduct(
    @Req() request: any,
    @Body() body: any,
  ) {
    return this.productsService.createProduct(
      request.user.uid,
      body,
    );
  }

  @Get('merchant/products')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  async getMerchantProducts(
    @Req() request: any,
  ) {
    return this.productsService.getMerchantProducts(
      request.user.uid,
    );
  }

  @Patch('merchant/products/:productId')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  async updateProduct(
    @Req() request: any,
    @Param('productId') productId: string,
    @Body() body: any,
  ) {
    return this.productsService.updateProduct(
      request.user.uid,
      productId,
      body,
    );
  }

  @Patch('merchant/products/:productId/availability')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  async updateAvailability(
    @Req() request: any,
    @Param('productId') productId: string,
    @Body('isAvailable') isAvailable: boolean,
  ) {
    return this.productsService.updateAvailability(
      request.user.uid,
      productId,
      isAvailable,
    );
  }

  @Delete('merchant/products/:productId')
  @UseGuards(AuthGuard, RolesGuard)
  @Roles('MERCHANT')
  async deleteProduct(
    @Req() request: any,
    @Param('productId') productId: string,
  ) {
    return this.productsService.deleteProduct(
      request.user.uid,
      productId,
    );
  }

  // CUSTOMER

  @Get('stores/:storeId/products')
  @UseGuards(AuthGuard)
  async getStoreProducts(
    @Param('storeId') storeId: string,
    @Query('categoryId') categoryId?: string,
  ) {
    return this.productsService.getStoreProducts(
      storeId,
      categoryId,
    );
  }

  @Get('stores/:storeId/products/:productId')
  @UseGuards(AuthGuard)
  async getStoreProduct(
    @Param('storeId') storeId: string,
    @Param('productId') productId: string,
  ) {
    return this.productsService.getStoreProduct(
      storeId,
      productId,
    );
  }
}