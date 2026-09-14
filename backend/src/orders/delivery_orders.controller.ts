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
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { OrdersService } from './orders.service.js';

@Controller('delivery/orders')
@UseGuards(AuthGuard, RolesGuard)
@Roles('DELIVERY')
export class DeliveryOrdersController {
  constructor(
    private readonly ordersService: OrdersService,
  ) {}

  @Get()
  async getOrders(@Req() request: any) {
    return this.ordersService.getDeliveryOrders(request.user.uid);
  }

  @Get('history')
  async getHistory(@Req() request: any) {
    return this.ordersService.getDeliveryHistory(request.user.uid);
  }

  @Patch(':orderId/accept')
  async acceptOrder(
    @Req() request: any,
    @Param('orderId') orderId: string,
  ) {
    return this.ordersService.acceptDeliveryOrder(
      orderId,
      request.user.uid,
    );
  }

  @Patch(':orderId/status')
  async updateStatus(
    @Req() request: any,
    @Param('orderId') orderId: string,
    @Body('status') status: string,
  ) {
    return this.ordersService.updateDeliveryStatus(
      orderId,
      request.user.uid,
      status,
    );
  }

  @Post(':orderId/otp/generate')
async generateDeliveryOtp(
  @Req() request: any,
  @Param('orderId') orderId: string,
) {
  return this.ordersService.generateDeliveryOtp(
    orderId,
    request.user.uid,
  );
}

@Post(':orderId/otp/verify')
async verifyDeliveryOtp(
  @Req() request: any,
  @Param('orderId') orderId: string,
  @Body('otp') otp: string,
) {
  return this.ordersService.verifyDeliveryOtp(
    orderId,
    request.user.uid,
    otp,
  );
}
}
