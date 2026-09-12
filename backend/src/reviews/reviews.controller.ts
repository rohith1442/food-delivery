import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard.js';
import { ReviewsService } from './reviews.service.js';

@Controller('reviews')
@UseGuards(AuthGuard)
export class ReviewsController {
  constructor(
    private readonly reviewsService: ReviewsService,
  ) {}

  @Post()
  async createReview(
    @Req() request: any,
    @Body()
    body: {
      orderId: string;
      rating: number;
      comment?: string;
    },
  ) {
    return this.reviewsService.createReview(request.user.uid, body);
  }

  @Get('order/:orderId')
  async getOrderReview(
    @Req() request: any,
    @Param('orderId') orderId: string,
  ) {
    return this.reviewsService.getOrderReview(
      request.user.uid,
      orderId,
    );
  }

  @Get('store/:storeId')
  async getStoreReviews(@Param('storeId') storeId: string) {
    return this.reviewsService.getStoreReviews(storeId);
  }
}
