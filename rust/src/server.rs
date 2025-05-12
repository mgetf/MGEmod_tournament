use crate::ForwardMessage;
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

    fn handle(&mut self, msg: ForwardMessage, ctx: &mut Self::Context) {
        match msg.message {
            MessagePayload::Init {} => {
                self.admin = Some(msg.from.clone());
                println!("Admin initialized. Replying with IdiomorphUpdate.");

                let admin_client_addr = msg.from.clone();

                let reply_payload = MessagePayload::IdiomorphUpdate {
                    target_id: "app".to_string(),
                    html_content: format!(
                        "<div id='app'><h1>Server Acknowledged Init! Morphed Content.</h1></div>",
                    ),
                };
                admin_client_addr.do_send(crate::ForwardMessage {
                    message: reply_payload,
                    from: msg.from.clone(), // is this right?
                });
            }
            MessagePayload::ServerHello {} => {
                self.servers.push(msg.from);
            }
            MessagePayload::ServerAck {} => {}
            MessagePayload::Error { message } => {}
            MessagePayload::IdiomorphUpdate {
                target_id,
                html_content,
            } => {}
        }
    }
}
