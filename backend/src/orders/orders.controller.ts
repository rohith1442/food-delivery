import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { OrdersService } from './orders.service.js';

@Controller('orders')
@UseGuards(AuthGuard)
export class OrdersController {
  constructor(
    private readonly ordersService: OrdersService,
  ) {}

  @Post()
  async createOrder(
    @Req() request: any,
    @Body() body: any,
  ) {
    return this.ordersService.createOrder(
      request.user.uid,
      body,
    );
  }

  @Get()
  async getOrders(@Req() request: any) {
    return this.ordersService.getCustomerOrders(
      request.user.uid,
    );
  }

  @Get(':orderId')
  async getOrder(
    @Req() request: any,
    @Param('orderId') orderId: string,
  ) {
    return this.ordersService.getCustomerOrder(
      request.user.uid,
      orderId,
    );
  }

  @Patch(':orderId/cancel')
  async cancelOrder(
    @Req() request: any,
    @Param('orderId') orderId: string,
  ) {
    return this.ordersService.cancelOrder(
      request.user.uid,
      orderId,
    );
  }
}