import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { FirebaseService } from '../firebase/firebase.service.js';
import {
  ROLES_KEY,
  UserRole,
} from './roles.decorator.js';

interface UserDocument {
  role?: string;
  status?: string;
  isActive?: boolean;
}

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly firebaseService: FirebaseService,
  ) {}

  async canActivate(
    context: ExecutionContext,
  ): Promise<boolean> {
    const requiredRoles =
      this.reflector.getAllAndOverride<UserRole[]>(
        ROLES_KEY,
        [
          context.getHandler(),
          context.getClass(),
        ],
      );

    if (
      !requiredRoles ||
      requiredRoles.length === 0
    ) {
      return true;
    }

    const request =
      context.switchToHttp().getRequest();

    const uid =
      request.user?.uid;

    if (!uid) {
      throw new ForbiddenException(
        'Authenticated user is required',
      );
    }

    const user =
      (await this.firebaseService
        .getUserById(
          uid,
        )) as UserDocument | null;

    if (!user) {
      throw new ForbiddenException(
        'User profile not found',
      );
    }

    const role =
      user.role
        ?.trim()
        .toUpperCase();

    const status =
      user.status
        ?.trim()
        .toUpperCase();

    if (!role) {
      throw new ForbiddenException(
        'User role is not configured',
      );
    }

    if (
      !requiredRoles.includes(
        role as UserRole,
      )
    ) {
      throw new ForbiddenException(
        'You are not authorized to access this resource',
      );
    }

    if (
      status !== 'ACTIVE' ||
      user.isActive !== true
    ) {
      throw new ForbiddenException(
        'Your account is not active',
      );
    }

    request.user.role =
      role;

    request.user.status =
      status;

    return true;
  }
}