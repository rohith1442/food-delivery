import {
  Body,
  Controller,
  Get,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { OrdersService } from './orders.service.js';

@Controller('delivery/profile')
@UseGuards(AuthGuard)
export class DeliveryPartnerController {
  constructor(
    private readonly ordersService: OrdersService,
  ) {}

  @Get()
  async getProfile(@Req() request: any) {
    return this.ordersService.getDeliveryPartnerProfile(
      request.user.uid,
    );
  }

  @Patch('availability')
  async updateAvailability(
    @Req() request: any,
    @Body()
    body: {
      zoneId?: string;
      isOnline?: boolean;
    },
  ) {
    return this.ordersService.updateDeliveryPartnerAvailability(
      request.user.uid,
      body,
    );
  }
}
