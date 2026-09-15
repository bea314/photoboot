import { Body, Controller, Get, Param, Patch } from '@nestjs/common';
import { EventsService } from './events.service';
import { UpdateEventDto } from './dto/update-event.dto';

@Controller('events')
export class EventsController {
  constructor(private readonly eventsService: EventsService) {}

  @Get('current')
  getCurrent() {
    return this.eventsService.getCurrent();
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateEventDto) {
    return this.eventsService.update(id, dto);
  }
}
