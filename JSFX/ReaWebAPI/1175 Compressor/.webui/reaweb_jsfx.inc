// ReaWebAPI JSFX channel v1. Reserve 32768 local words at memory before calling init.
@init
function reaweb_jsfx_touch(bank,length) local(i) (
  i=0;while(i<length)(bank[i]+=0;i+=65536;);
  length>0 ? bank[length-1]+=0;
);
function reaweb_jsfx_init(base, memory) local(i,existing) (
  existing=reaweb_jsfx_epoch>0 && reaweb_jsfx_base==base && reaweb_jsfx_memory==memory;
  base>=0 && base<=4194304 && base==floor(base) && memory>=0 && memory==floor(memory) && memory+32768<=__memtop() ? (
  reaweb_jsfx_base = base;
  reaweb_jsfx_memory = memory;
  !existing ? (reaweb_jsfx_slot=-1;reaweb_jsfx_token=0;reaweb_jsfx_channel_epoch=0;);
  reaweb_jsfx_clock = 0;
  reaweb_jsfx_sequence = 0;
  reaweb_jsfx_dropped = 0;
  reaweb_jsfx_clock_epoch = 0;
  reaweb_jsfx_previous_rate = 0;
  reaweb_jsfx_previous_position = 0;
  reaweb_jsfx_previous_state = -1;
  reaweb_jsfx_reply_pending = 0;
  reaweb_jsfx_stream_mask = 0;
  reaweb_jsfx_state_count = 0;
  reaweb_jsfx_resource_count = 0;
  memory[32766]!=1381452337 ? (i=16384;loop(1024,memory[i]=0;i+=1;);memory[32766]=1381452337;);
  i=0;loop(24,memory[16384+i*16+7]=0;i+=1;);
  atomic_setifequal(gmem[base], 0, 1381452337);
  reaweb_jsfx_epoch = gmem[base] == 1381452337 ? atomic_add(gmem[base+1], 1) : 0;
  reaweb_jsfx_scan_generation = -1;
  reaweb_jsfx_touch(memory,32768);
  reaweb_jsfx_epoch;
  ) : (reaweb_jsfx_slot=-1;reaweb_jsfx_token=0;reaweb_jsfx_epoch=0;0;);
);

// A live VM can renew its existing lease without writing a host parameter.
function reaweb_jsfx_renew() local(addr,ok) (
  ok=0;addr=reaweb_jsfx_slot;
  addr>=0 && reaweb_jsfx_channel_epoch!=reaweb_jsfx_epoch && atomic_setifequal(gmem[addr],1,2)==1 ? (
    gmem[addr+1]==reaweb_jsfx_token && gmem[addr+2]==reaweb_jsfx_channel_epoch ? (
      gmem[addr+2]=reaweb_jsfx_epoch;gmem[addr+3]=0;gmem[addr+8]=0;gmem[addr+9]=0;
      gmem[addr+16]=0;gmem[addr+17]=0;gmem[addr+23]=0;
      gmem[addr+24]=reaweb_jsfx_state_count;gmem[addr+25]=reaweb_jsfx_resource_count;
      gmem[addr+26]=reaweb_jsfx_serialize_error;
      reaweb_jsfx_channel_epoch=reaweb_jsfx_epoch;reaweb_jsfx_session_changed=1;ok=1;
    ) : (reaweb_jsfx_slot=-1;reaweb_jsfx_token=0;);
    atomic_set(gmem[addr],1);
  );
  ok;
);
// The target slider must expose this fresh response before the host accepts a lease.
function reaweb_jsfx_handshake(request) local(slot,addr,generation,acquired,retry) (
  reaweb_jsfx_token > 0 ? reaweb_jsfx_renew();
  reaweb_jsfx_token == 0 && reaweb_jsfx_epoch > 0 ? (
    generation=atomic_get(gmem[reaweb_jsfx_base+3]);
    generation != reaweb_jsfx_scan_generation ? (
      slot=0;retry=0;
      loop(32,
        addr=reaweb_jsfx_base+65536+slot*65536;
        acquired=atomic_setifequal(gmem[addr],1,2);
        acquired==1 ? (
          reaweb_jsfx_token==0 && gmem[addr+2]==0 && gmem[addr+28]==reaweb_jsfx_epoch ? (
            reaweb_jsfx_epoch=atomic_add(gmem[reaweb_jsfx_base+1],1);
            reaweb_jsfx_slot=addr;reaweb_jsfx_token=gmem[addr+1];
            reaweb_jsfx_channel_epoch=reaweb_jsfx_epoch;reaweb_jsfx_session_changed=1;
            reaweb_jsfx_reply_pending=0;
            gmem[addr+2]=reaweb_jsfx_epoch;gmem[addr+28]=0;
            gmem[addr+22]=1;gmem[addr+24]=reaweb_jsfx_state_count;
            gmem[addr+25]=reaweb_jsfx_resource_count;gmem[addr+26]=reaweb_jsfx_serialize_error;
          );
          atomic_set(gmem[addr],1);
        ) : acquired>1 ? retry=1;
        slot+=1;
      );
      !retry ? reaweb_jsfx_scan_generation=generation;
    );
  );
  -reaweb_jsfx_epoch;
);

function reaweb_jsfx_banks_free(category,id,a,b,capacity) local(i,record,other,n,ok) (
  i=0;ok=1;
  loop(24,
    record=reaweb_jsfx_memory+16384+i*16;
    record[7] && i!=(category==1?id:id+16) ? (
      n=record[3];other=record[0];
      (a<other+n && other<a+capacity) || (b<other+n && other<b+capacity) ? ok=0;
      other=record[1];
      (a<other+n && other<a+capacity) || (b<other+n && other<b+capacity) ? ok=0;
    );i+=1;
  );
  ok;
);

// State uses two caller-owned banks. Encoded values follow the declared schema.
function reaweb_jsfx_state(id, bank_a, bank_b, length, capacity, schema_version, read_only) local(record,existing) (
  id>=0 && id<16 && id==floor(id) && length>=0 && length<=capacity && capacity<=4096 &&
      length==floor(length) && capacity==floor(capacity) && bank_a>=0 && bank_b>=0 &&
      bank_a==floor(bank_a) && bank_b==floor(bank_b) && abs(bank_a-bank_b)>=capacity &&
      bank_a+capacity<=__memtop() && bank_b+capacity<=__memtop() &&
      (bank_a+capacity<=reaweb_jsfx_memory || bank_a>=reaweb_jsfx_memory+32768) &&
      (bank_b+capacity<=reaweb_jsfx_memory || bank_b>=reaweb_jsfx_memory+32768) &&
      schema_version>0 && schema_version<=65535 && schema_version==floor(schema_version) &&
      reaweb_jsfx_banks_free(1,id,bank_a,bank_b,capacity) ? (
    record=reaweb_jsfx_memory+16384+id*16;
    existing=record[9] && record[3]==capacity && record[4]==schema_version &&
      ((record[0]==bank_a && record[1]==bank_b) || (record[0]==bank_b && record[1]==bank_a));
    !existing ? (
      record[0]=bank_a;record[1]=bank_b;record[2]=length;record[3]=capacity;
      record[4]=schema_version;record[5]=0;record[6]=0;record[9]=1;record[12]=0;record[13]=0;
    );
    record[7]=1;record[8]=read_only;
    reaweb_jsfx_state_count=max(reaweb_jsfx_state_count,id+1);
    reaweb_jsfx_touch(bank_a,capacity);reaweb_jsfx_touch(bank_b,capacity);
    existing ? 2 : 1;
  ) : 0;
);
function reaweb_jsfx_state_data(id) local(record) (
  record=reaweb_jsfx_memory+16384+id*16;
  id>=0 && id<16 && id==floor(id) && record[7] ? record[0] : -1;
);
function reaweb_jsfx_state_swap(id,length) local(record,previous,ok) (
  ok=0;
  id>=0 && id<16 ? (
    record=reaweb_jsfx_memory+16384+id*16;
    record[7] && length>=0 && length<=record[3] && (record[5]<4294967295 || record[6]<4294967295) ? (
      previous=record[0];record[0]=record[1];record[1]=previous;record[2]=length;
      record[5]+=1;record[5]>=4294967296 ? (record[5]=0;record[6]+=1;);
      ok=1;
    );
  );
  ok;
);
function reaweb_jsfx_state_update(id,data,length) local(record,bank,i,ok) (
  ok=0;
  id>=0 && id<16 && id==floor(id) && atomic_setifequal(reaweb_jsfx_state_gate,0,1)==0 ? (
    record=reaweb_jsfx_memory+16384+id*16;
    record[7] && !record[12] && length>=0 && length==floor(length) && length<=record[3] &&
        data>=0 && data==floor(data) && data+length<=__memtop() ? (
      bank=record[1];i=0;loop(length,bank[i]=data[i];i+=1;);
      ok=reaweb_jsfx_state_swap(id,length);
    );
    atomic_set(reaweb_jsfx_state_gate,0);
  );
  ok;
);

// Resource formats: 1 = bytes, 2 = float32 values. Banks are caller-owned.
function reaweb_jsfx_resource(id,bank_a,bank_b,length,capacity,format) local(record,existing,meta) (
  id>=0 && id<8 && id==floor(id) && length>=0 && length<=capacity && capacity>0 &&
      length==floor(length) && capacity==floor(capacity) && capacity<=33554432 &&
      bank_a>=0 && bank_b>=0 && bank_a==floor(bank_a) && bank_b==floor(bank_b) &&
      bank_a+capacity<=__memtop() && bank_b+capacity<=__memtop() &&
      (bank_a+capacity<=reaweb_jsfx_memory || bank_a>=reaweb_jsfx_memory+32768) &&
      (bank_b+capacity<=reaweb_jsfx_memory || bank_b>=reaweb_jsfx_memory+32768) &&
      abs(bank_a-bank_b)>=capacity && (format==1 || format==2) &&
      reaweb_jsfx_banks_free(2,id,bank_a,bank_b,capacity) ? (
    record=reaweb_jsfx_memory+16640+id*16;
    existing=record[9] && record[3]==capacity && record[4]==format &&
      ((record[0]==bank_a && record[1]==bank_b) || (record[0]==bank_b && record[1]==bank_a));
    !existing ? (
      record[0]=bank_a;record[1]=bank_b;record[2]=length;record[3]=capacity;
      record[4]=format;record[5]=0;record[6]=0;record[9]=1;record[12]=0;record[13]=0;
      record[14]=reaweb_jsfx_memory+17408+id*1538;record[15]=record[14]+769;
      meta=record[14];meta[0]=0;meta=record[15];meta[0]=0;
    );
    record[7]=1;record[8]=0;record[10]=0;record[11]=0;
    reaweb_jsfx_resource_count=max(reaweb_jsfx_resource_count,id+1);
    // Touch every memory page before audio processing begins.
    reaweb_jsfx_touch(bank_a,capacity);reaweb_jsfx_touch(bank_b,capacity);
    existing ? 2 : 1;
  ) : 0;
);
function reaweb_jsfx_resource_data(id) local(record) (
  record=reaweb_jsfx_memory+16640+id*16;
  id>=0 && id<8 && id==floor(id) && record[7] ? record[0] : -1;
);
function reaweb_jsfx_resource_length(id) local(record) (
  record=reaweb_jsfx_memory+16640+id*16;
  id>=0 && id<8 && id==floor(id) && record[7] ? record[2] : 0;
);
function reaweb_jsfx_resource_swap(id,length) local(record,previous,ok) (
  ok=0;
  id>=0 && id<8 ? (
    record=reaweb_jsfx_memory+16640+id*16;
    record[7] && length>=0 && length<=record[3] && (record[5]<4294967295 || record[6]<4294967295) ? (
      previous=record[0];record[0]=record[1];record[1]=previous;record[2]=length;
      record[5]+=1;record[5]>=4294967296 ? (record[5]=0;record[6]+=1;);
      previous=record[14];record[14]=record[15];record[15]=previous;
      record[11]=0;ok=1;
    );
  );
  ok;
);

function reaweb_jsfx_acquire() local(addr, ok, acquired) (
  addr = reaweb_jsfx_slot;
  ok = 0;
  acquired=addr>=0 ? atomic_setifequal(gmem[addr], 1, 2) : -1;
  acquired == 1 ? (
    gmem[addr+1] == reaweb_jsfx_token && gmem[addr+2] == reaweb_jsfx_epoch ? ok = 1 : (
      atomic_set(gmem[addr], 1);
      reaweb_jsfx_slot = -1;
      reaweb_jsfx_token = 0;
      reaweb_jsfx_stream_mask = 0;
      reaweb_jsfx_scan_generation = -1;
    );
  ) : acquired==0 ? (
    reaweb_jsfx_slot=-1;reaweb_jsfx_token=0;reaweb_jsfx_stream_mask=0;
    reaweb_jsfx_scan_generation=-1;
  );
  ok;
);

function reaweb_jsfx_release() ( atomic_set(gmem[reaweb_jsfx_slot], 1); );

// Long-running commands check once per @block and finish with reply code 6.
function reaweb_jsfx_cancelled() local(cancelled) (
  cancelled=reaweb_jsfx_slot<0;
  reaweb_jsfx_acquire() ? (
    cancelled=gmem[reaweb_jsfx_slot+9]!=reaweb_jsfx_request || gmem[reaweb_jsfx_slot+23];
    reaweb_jsfx_release();
  );
  cancelled;
);

// Call once per @block. A busy helper drops telemetry work, never waits for it.
function reaweb_jsfx_block() local(addr, i) (
  reaweb_jsfx_renew();
  reaweb_jsfx_command_ready = 0;
  (srate != reaweb_jsfx_previous_rate || play_state != reaweb_jsfx_previous_state ||
      abs(play_position-reaweb_jsfx_previous_position) > 2*samplesblock/max(1,srate)) ? reaweb_jsfx_clock_epoch += 1;
  reaweb_jsfx_previous_rate = srate;
  reaweb_jsfx_previous_state = play_state;
  reaweb_jsfx_previous_position = play_position + ((play_state&1) ? samplesblock/max(1,srate) : 0);
  reaweb_jsfx_clock += samplesblock;
  reaweb_jsfx_acquire() ? (
    addr = reaweb_jsfx_slot;
    gmem[addr+3] += 1;
    gmem[addr+4] = reaweb_jsfx_clock;
    gmem[addr+5] = srate;
    gmem[addr+6] = num_ch;
    gmem[addr+7] = play_state;
    gmem[addr+20] = play_position;
    gmem[addr+21] = reaweb_jsfx_clock_epoch;
    gmem[addr+18] = reaweb_jsfx_dropped;
    reaweb_jsfx_stream_mask = gmem[addr+27];
    reaweb_jsfx_command_ready = gmem[addr+8] == 1;
    reaweb_jsfx_reply_pending && gmem[addr+8] == 2 && gmem[addr+9] == reaweb_jsfx_request ? (
      i = 0;
      loop(reaweb_jsfx_reply_length,
        gmem[addr+8256+i] = reaweb_jsfx_memory[8192+i]; i += 1;
      );
      gmem[addr+13] = reaweb_jsfx_reply_code;
      gmem[addr+14] = reaweb_jsfx_reply_length;
      gmem[addr+8] = 3;
      reaweb_jsfx_reply_pending = 0;
    );
    reaweb_jsfx_release();
  );
);

// Returns a command kind, or zero. Input values remain in the reserved local area.
function reaweb_jsfx_poll() local(addr, i, kind) (
  kind = 0;
  !reaweb_jsfx_reply_pending && reaweb_jsfx_acquire() ? (
    addr = reaweb_jsfx_slot;
    gmem[addr+8] == 1 ? (
      reaweb_jsfx_request = gmem[addr+9];
      reaweb_jsfx_id = gmem[addr+11];
      reaweb_jsfx_length = gmem[addr+12];
      reaweb_jsfx_owner = gmem[addr+15];
      reaweb_jsfx_length >= 0 && reaweb_jsfx_length <= 8192 ? (
        i = 0;
        loop(reaweb_jsfx_length,
          reaweb_jsfx_memory[i] = gmem[addr+64+i]; i += 1;
        );
        kind = gmem[addr+10];
        gmem[addr+8] = 2;
      );
    );
    reaweb_jsfx_release();
  );
  kind;
);
function reaweb_jsfx_value(index) (
  index >= 0 && index < reaweb_jsfx_length ? reaweb_jsfx_memory[index] : 0;
);
// Owned notes use the caller's current MIDI bus. No global all-notes-off is sent.
function reaweb_jsfx_note_on(channel,note,velocity) local(i,record,found,empty,key,bus,ok,busy) (
  ok=0;bus=ext_midi_bus?midi_bus:0;key=channel*128+note;
  reaweb_jsfx_owner>0 && channel>=0 && channel<16 && channel==floor(channel) &&
      note>=0 && note<128 && note==floor(note) && velocity>0 && velocity<128 && velocity==floor(velocity) && bus>=0 && bus<16 && bus==floor(bus) ? (
    i=0;found=-1;empty=-1;busy=0;
    loop(128,
      record=reaweb_jsfx_memory+16800+i*4;
      record[0]==reaweb_jsfx_owner && record[1]==key && record[3]==bus ? found=record;
      record[0]>0 && record[0]!=reaweb_jsfx_owner && record[1]==key && record[3]==bus ? busy=1;
      record[0]==0 ? empty=record;i+=1;
    );
    found<0 ? found=empty;
    found>=0 && !busy ? (
      found[2]!=0 ? (
        midisend(0,128+channel,note,0) ? (found[0]=0;found[2]=0;)
          : (found[2]=-1;reaweb_jsfx_note_retry=1;);
      );
      found[2]==0 && midisend(0,144+channel,note,velocity) ? (
        found[0]=reaweb_jsfx_owner;found[1]=key;found[2]=1;found[3]=bus;ok=1;
      );
    );
  );ok;
);
function reaweb_jsfx_note_off(channel,note) local(i,record,key,ok,bus) (
  i=0;ok=0;key=channel*128+note;bus=ext_midi_bus?midi_bus:0;
  reaweb_jsfx_owner>0 && channel>=0 && channel<16 && channel==floor(channel) && note>=0 && note<128 && note==floor(note) ? loop(128,
    record=reaweb_jsfx_memory+16800+i*4;
    record[0]==reaweb_jsfx_owner && record[1]==key && record[3]==bus && record[2]!=0 ? (
      midisend(0,128+channel,note,0) ? (record[0]=0;record[2]=0;ok=1;)
        : (record[2]=-1;reaweb_jsfx_note_retry=1;);
    );i+=1;
  );ok;
);
function reaweb_jsfx_release_notes(owner) local(i,record,channel,note,bus) (
  i=0;bus=midi_bus;reaweb_jsfx_note_retry=0;
  loop(128,
    record=reaweb_jsfx_memory+16800+i*4;
    record[0]>0 && (owner==0 || record[0]==owner || record[2]<0) ? (
      channel=floor(record[1]/128);note=record[1]%128;midi_bus=record[3];
      midisend(0,128+channel,note,0) ? (record[0]=0;record[2]=0;)
        : (record[2]=-1;reaweb_jsfx_note_retry=1;);
    );i+=1;
  );midi_bus=bus;
);
function reaweb_jsfx_note_count() local(i,record,count) (
  i=0;count=0;loop(128,record=reaweb_jsfx_memory+16800+i*4;count+=abs(record[2]);i+=1;);count;
);
function reaweb_jsfx_reply(code, data, length) local(i) (
  length >= 0 && length <= 8192 && !reaweb_jsfx_reply_pending ? (
    i = 0;
    loop(length, reaweb_jsfx_memory[8192+i] = data[i]; i += 1;);
    reaweb_jsfx_reply_code = code;
    reaweb_jsfx_reply_length = length;
    reaweb_jsfx_reply_pending = 1;
    1;
  ) : 0;
);

// Publish explicitly selected samples or telemetry. At most 4096 scalar values.
function reaweb_jsfx_stream_active(id) (
  id>=0 && id<8 && id==floor(id) && (reaweb_jsfx_stream_mask & (2^id));
);
function reaweb_jsfx_publish(id, data, length, channels, first_sample) local(addr, write, read, packet, i, ok) (
  ok = 0;
  length > 0 && length <= 4096 && channels > 0 && channels <= 32 && reaweb_jsfx_stream_active(id) ? (
    reaweb_jsfx_sequence += 1;
    reaweb_jsfx_acquire() ? (
    addr = reaweb_jsfx_slot;
    write = gmem[addr+16]; read = gmem[addr+17];
    write-read < 8 ? (
      packet = addr+16448+(write%8)*4112;
      gmem[packet] = id;
      gmem[packet+1] = length;
      gmem[packet+2] = channels;
      gmem[packet+3] = srate;
      gmem[packet+4] = first_sample;
      gmem[packet+5] = reaweb_jsfx_sequence;
      gmem[packet+6] = reaweb_jsfx_dropped;
      gmem[packet+7] = reaweb_jsfx_epoch;
      gmem[packet+8] = play_position;
      gmem[packet+9] = play_state;
      gmem[packet+10] = reaweb_jsfx_clock_epoch;
      i = 0;
      loop(length, gmem[packet+16+i] = data[i]; i += 1;);
      gmem[addr+16] = write+1;
      ok = 1;
    );
    reaweb_jsfx_release();
    );
    !ok ? reaweb_jsfx_dropped += 1;
  );
  ok;
);

// Call in @block instead of block/poll when using registered state capabilities.
// Unhandled command kinds are returned to the effect's bounded command handler.
function reaweb_jsfx_service() local(kind,id,record,length,bank,i,out,code,offset,meta) (
  reaweb_jsfx_block();kind=0;
  reaweb_jsfx_note_token!=reaweb_jsfx_token || reaweb_jsfx_note_epoch!=reaweb_jsfx_epoch ? (
    reaweb_jsfx_release_notes(0);reaweb_jsfx_released_owner=0;
    reaweb_jsfx_note_token=reaweb_jsfx_token;reaweb_jsfx_note_epoch=reaweb_jsfx_epoch;
  ) : reaweb_jsfx_released_owner=-1;
  reaweb_jsfx_note_retry ? reaweb_jsfx_release_notes(-1);
  atomic_setifequal(reaweb_jsfx_state_gate,0,1)==0 ? (
  i=0;loop(24,
    record=reaweb_jsfx_memory+16384+i*16;
    record[7] && record[12] ? (
      i<16 ? reaweb_jsfx_state_swap(i,record[12]-1) : reaweb_jsfx_resource_swap(i-16,record[12]-1);
      record[12]=0;
    );i+=1;
  );
  kind=reaweb_jsfx_command_ready ? reaweb_jsfx_poll() : 0;id=reaweb_jsfx_id;
  kind==9 ? (
    reaweb_jsfx_released_owner=reaweb_jsfx_value(0);
    reaweb_jsfx_release_notes(reaweb_jsfx_released_owner);
    reaweb_jsfx_reply(0,0,0);kind=0;
  );
  kind==2 || kind==3 ? (
    out=reaweb_jsfx_memory+8192;code=0;
    id<0 || id>=16 ? code=2 : (
      record=reaweb_jsfx_memory+16384+id*16;
      !record[7] ? code=2 : (
        kind==3 ? (
          length=reaweb_jsfx_value(3);
          record[8] ? code=3 :
          (reaweb_jsfx_value(1)!=record[5] || reaweb_jsfx_value(2)!=record[6]) ? code=1 :
          (reaweb_jsfx_length<4 || reaweb_jsfx_value(0)!=record[4] || length<0 ||
            length!=floor(length) || length>record[3] || length+4!=reaweb_jsfx_length) ? code=2 : (
            bank=record[1];i=0;loop(length,bank[i]=reaweb_jsfx_value(i+4);i+=1;);
            !reaweb_jsfx_state_swap(id,length) ? code=4;
          );
        );
        out[0]=record[4];out[1]=record[5];out[2]=record[6];out[3]=record[2];
        bank=record[0];i=0;loop(record[2],out[4+i]=bank[i];i+=1;);
      );
    );
    reaweb_jsfx_reply(code,out,code==2?0:4+record[2]);
    kind=0;
  );
  (kind>=4 && kind<=8) || kind==10 ? (
    out=reaweb_jsfx_memory+8192;code=0;length=0;
    id<0 || id>=8 ? code=2 : (
      record=reaweb_jsfx_memory+16640+id*16;
      !record[7] ? code=2 : (
        kind==4 ? (
          length=reaweb_jsfx_value(0);
          meta=reaweb_jsfx_length==1?0:reaweb_jsfx_value(1);
          record[11] ? code=5 :
          (length<0 || length!=floor(length) || length>record[3] || meta<0 || meta>768 || meta!=floor(meta) ||
            (reaweb_jsfx_length!=1 && reaweb_jsfx_length!=meta+2)) ? code=2 : (
            record[8]=0;record[10]=length;record[11]=1;
            bank=record[15];bank[0]=meta;i=0;loop(meta,bank[i+1]=reaweb_jsfx_value(i+2);i+=1;);
          );
        ) : kind==5 ? (
          offset=reaweb_jsfx_value(0);length=reaweb_jsfx_value(1);
          !record[11] || reaweb_jsfx_length<2 || length<0 || length!=floor(length) ||
            length+2!=reaweb_jsfx_length || offset!=record[8] || offset+length>record[10] ? code=2 : (
            bank=record[1];i=0;loop(length,bank[offset+i]=reaweb_jsfx_value(i+2);i+=1;);record[8]+=length;
          );
        ) : kind==6 ? (
          reaweb_jsfx_value(0)!=record[5] || reaweb_jsfx_value(1)!=record[6] ? code=1 :
          !record[11] || reaweb_jsfx_length!=2 || record[8]!=record[10] ? code=2 : (
            !reaweb_jsfx_resource_swap(id,record[10]) ? code=4;
          );
        ) : kind==8 ? (record[11]=0;record[8]=0;record[10]=0;);
        out[0]=record[5];out[1]=record[6];out[2]=record[2];out[3]=record[4];out[4]=record[3];length=5;
        kind==10 || kind==6 ? (
          bank=record[14];out[5]=bank[0];i=0;loop(bank[0],out[6+i]=bank[i+1];i+=1;);length=6+bank[0];
        );
        kind==7 ? (
          offset=reaweb_jsfx_value(2);i=reaweb_jsfx_value(3);
          reaweb_jsfx_value(0)!=record[5] || reaweb_jsfx_value(1)!=record[6] ? code=1 :
          (reaweb_jsfx_length!=4 || offset<0 || offset!=floor(offset) || i<0 || i!=floor(i) ||
            i>4096 || offset+i>record[2]) ? code=2 : (
            out[4]=offset;out[5]=i;length=6+i;bank=record[0];i=0;
            loop(length-6,out[6+i]=bank[offset+i];i+=1;);
          );
        );
      );
    );
    reaweb_jsfx_reply(code,out,length);kind=0;
  );
  atomic_set(reaweb_jsfx_state_gate,0);
  );
  kind;
);

// Call only from the effect's @serialize section, after its own existing fields.
// Big-endian binary strings retain double precision and avoid file_mem's float conversion.
function reaweb_jsfx_serialize(file,state_mask,resource_mask) local(reading,count,id,category,record,length,bank,i,n,j,width,type,valid,version,mask,meta) (
  // The non-audio serialization context waits only for bounded SDK state copies.
  // Audio processing skips control work while serialization owns this gate.
  while(atomic_setifequal(reaweb_jsfx_state_gate,0,2)!=0);
  reading=file_avail(file)>=0;
  reading ? (
    i=0;loop(24,
      record=reaweb_jsfx_memory+16384+i*16;record[12]=0;record[13]=0;
      i>=16 ? record[11]=0;
      i+=1;
    );
  );
  !reading ? (
    count=0;id=0;loop(16,(state_mask&(2^id)) && reaweb_jsfx_memory[16384+id*16+7] ? count+=1;id+=1;);
    id=0;loop(8,(resource_mask&(2^id)) && reaweb_jsfx_memory[16640+id*16+7] ? count+=1;id+=1;);
    #reaweb_jsfx_serial="";
    str_setchar(#reaweb_jsfx_serial,0,1381452337,'Iu');
    str_setchar(#reaweb_jsfx_serial,4,2,'Iu');str_setchar(#reaweb_jsfx_serial,8,count,'Iu');
  );
  file_string(file,#reaweb_jsfx_serial);
  valid=strlen(#reaweb_jsfx_serial)==12 && str_getchar(#reaweb_jsfx_serial,0,'Iu')==1381452337 &&
    str_getchar(#reaweb_jsfx_serial,4,'Iu')==2;
  count=str_getchar(#reaweb_jsfx_serial,8,'Iu');
  count>24 ? valid=0;
  category=1;id=0;
  loop(valid?count:0,
    !reading ? (
      while(category<=2 && (id>=(category==1?16:8) ||
          !((category==1?state_mask:resource_mask)&(2^id)) ||
          !reaweb_jsfx_memory[(category==1?16384:16640)+id*16+7])) (
        id+=1;id>=(category==1?16:8) ? (category+=1;id=0;);
      );
      record=reaweb_jsfx_memory+(category==1?16384:16640)+id*16;
      #reaweb_jsfx_serial="";str_setchar(#reaweb_jsfx_serial,0,category,'Iu');
      str_setchar(#reaweb_jsfx_serial,4,id,'Iu');str_setchar(#reaweb_jsfx_serial,8,record[4],'Iu');
      str_setchar(#reaweb_jsfx_serial,12,record[12]?record[12]-1:record[2],'Iu');
    );
    valid ? (
      file_string(file,#reaweb_jsfx_serial);
      category=str_getchar(#reaweb_jsfx_serial,0,'Iu');id=str_getchar(#reaweb_jsfx_serial,4,'Iu');
      version=str_getchar(#reaweb_jsfx_serial,8,'Iu');length=str_getchar(#reaweb_jsfx_serial,12,'Iu');
      valid=strlen(#reaweb_jsfx_serial)==16 && (category==1 || category==2) && id<(category==1?16:8);
      valid ? (
        record=reaweb_jsfx_memory+(category==1?16384:16640)+id*16;
        valid=record[7] && record[4]==version && length<=record[3] && (!reading || !record[13]) &&
          ((category==1?state_mask:resource_mask)&(2^id));
      );
      valid ? (
        bank=record[(reading || record[12])?1:0];width=category==1?8:(version==1?1:4);type=category==1?'D':(version==1?'cu':'F');
        i=0;
        while(i<length && valid) (
          n=min(512,length-i);
          !reading ? (
            #reaweb_jsfx_serial="";j=0;
            loop(n,str_setchar(#reaweb_jsfx_serial,j*width,bank[i+j],type);j+=1;);
          );
          file_string(file,#reaweb_jsfx_serial);
          strlen(#reaweb_jsfx_serial)!=n*width ? valid=0;
          reading && valid ? (j=0;loop(n,bank[i+j]=str_getchar(#reaweb_jsfx_serial,j*width,type);j+=1;););
          i+=n;
        );
        category==2 && valid ? (
          meta=record[(reading || record[12])?15:14];
          !reading ? (
            #reaweb_jsfx_serial="";j=0;
            loop(meta[0],str_setchar(#reaweb_jsfx_serial,j,meta[j+1],'cu');j+=1;);
          );
          file_string(file,#reaweb_jsfx_serial);n=strlen(#reaweb_jsfx_serial);
          n>768 ? valid=0;
          reading && valid ? (meta[0]=n;j=0;loop(n,meta[j+1]=str_getchar(#reaweb_jsfx_serial,j,'cu');j+=1;););
        );
        reading && valid ? record[13]=length+1;
      );
    );
    id+=1;
  );
  reading ? (
    i=0;loop(24,
      record=reaweb_jsfx_memory+16384+i*16;
      valid ? record[12]=record[13];
      record[13]=0;i+=1;
    );
    reaweb_jsfx_reply_pending=0;
    reaweb_jsfx_epoch=atomic_add(gmem[reaweb_jsfx_base+1],1);
  );
  atomic_set(reaweb_jsfx_state_gate,0);
  reaweb_jsfx_serialize_error=!valid;
  valid;
);

