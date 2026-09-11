import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';

import { AuthService } from './auth.service.js';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly authService: AuthService,
  ) {}

  async canActivate(
    context: ExecutionContext,
  ): Promise<boolean> {
    console.log('=== AUTH GUARD CALLED ===');
    const request = context.switchToHttp().getRequest();
    console.log('authorization:', request.headers.authorization);

    const authorization = request.headers.authorization;

    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException(
        'Authorization token is required',
      );
    }

    const token = authorization.substring(7);

    const decodedToken =
      await this.authService.verifyToken(token);

    request.user = decodedToken;

    console.log('decodedToken:', decodedToken);

    return true;
  }
}