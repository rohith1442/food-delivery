import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { OrdersService } from './orders.service.js';

@Controller('merchant/orders')
@UseGuards(AuthGuard, RolesGuard)
@Roles('MERCHANT')
export class MerchantOrdersController {
  constructor(
    private readonly ordersService: OrdersService,
  ) {}

  @Get()
  async getOrders(
    @Req() request: any,
  ) {
    return this.ordersService.getMerchantOrders(
      request.user.uid,
    );
  }

  @Patch(':orderId/status')
  async updateStatus(
    @Req() request: any,
    @Param('orderId') orderId: string,
    @Body('status') status: string,
  ) {
    return this.ordersService.updateOrderStatus(
      request.user.uid,
      orderId,
      status,
    );
  }
}