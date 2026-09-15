import {
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';

type TokenUser = { id: string; email: string };

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { email: dto.email.toLowerCase().trim() },
    });
    if (!user) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const ok = await bcrypt.compare(dto.password, user.passwordHash);
    if (!ok) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.issueTokens({ id: user.id, email: user.email });
  }

  async refresh(refreshToken: string) {
    let payload: { sub: string; email: string; typ?: string };
    try {
      payload = this.jwtService.verify(refreshToken);
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    if (payload.typ !== 'refresh') {
      throw new UnauthorizedException('Invalid refresh token');
    }

    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
    });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return this.issueTokens({ id: user.id, email: user.email });
  }

  logout() {
    return;
  }

  private issueTokens(user: TokenUser) {
    const accessToken = this.jwtService.sign(
      { sub: user.id, email: user.email, typ: 'access' },
      { expiresIn: '15m' },
    );
    const refreshToken = this.jwtService.sign(
      { sub: user.id, email: user.email, typ: 'refresh' },
      { expiresIn: '7d' },
    );

    return {
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email },
    };
  }
}
