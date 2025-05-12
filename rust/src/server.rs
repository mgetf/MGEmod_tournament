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

pub fn update(admin_client_addr: actix::Addr<crate::ServerWs>, new_html_content: Markup) {
    let reply_payload = MessagePayload::IdiomorphUpdate {
        target_id: "app".to_string(),
        html_content: new_html_content.into_string(),
    };
    admin_client_addr.do_send(crate::ForwardMessage {
        message: reply_payload,
        from: admin_client_addr.clone(),
    });
}

use maud::{html, Markup};

impl Handler<crate::ForwardMessage> for Ladder {
    type Result = ();

    fn handle(&mut self, msg: ForwardMessage, ctx: &mut Self::Context) {
        match msg.message {
            MessagePayload::Init {} => {
                self.admin = Some(msg.from.clone());
                update(msg.from, html! {
                    div #app {
                        h1 { "Server Acknowledged Init! Morphed Content." }
                    }
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
