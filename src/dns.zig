const std = @import("std");

pub const protocol = @import("dns/protocol.zig");
pub const client = @import("dns/client.zig");

pub const DnsClient = client.DnsClient;
pub const DnsConfig = client.DnsConfig;
