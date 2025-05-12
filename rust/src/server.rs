use actix::prelude::*;

const NUM_ARENAS: usize = 16;

pub struct Ladder {
    admin: Option<actix::Addr<crate::ServerWs>>,
    servers: Vec<actix::Addr<crate::ServerWs>>,
    players: Vec<crate::Player>,
}

impl Ladder {
    pub fn new() -> Self {
        Ladder {
            admin: None,
            servers: vec![],
            players: vec![],
        }
    }
}

impl Actor for Ladder {
    type Context = Context<Self>;
}

use crate::MessagePayload;
use reqwest;

impl StreamHandler<Result<Response<()>, reqwest::Error>> for Ladder {
    fn handle(&mut self, msg: Result<Response<()>, reqwest::Error>, _ctx: &mut Self::Context) {
        match msg {
            Ok(resp) => {
                println!("got response {:?}", resp);
            }
            Err(err) => {
                println!("got error {:?}", err);
            }
        }
    }
}

impl Handler<crate::ForwardMessage> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: crate::ForwardMessage, _ctx: &mut Self::Context) {
        match msg.message {
            MessagePayload::ServerHello { } => {
                self.servers.push(msg.from);
            }
            MessagePayload::ServerAck { } => {
                println!("server ack");
            }
            MessagePayload::Error { message } => {
                println!("error: {}", message);
            }
        }
    }
}
