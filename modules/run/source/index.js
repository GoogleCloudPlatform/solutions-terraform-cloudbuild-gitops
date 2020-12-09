const express = require('express');
const app = express();
const fs = require('fs');
const {PubSub} = require('@google-cloud/pubsub');
const bodyParser = require("body-parser");

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({extended:true}));

app.get('/', (req, res) => {
    fs.readFile('./index.html', null, function (error, data) {
        if (error) {
            res.writeHead(404);
            res.write('Whoops! File not found!');
        } else {
            res.write(data);
        }
        res.end();
    });
});

app.post('/creditapproval', (req, res , next) => {
    var projectId = 'cap-multicloud-_ENV_'; // Your Google Cloud Platform project ID
    
    // Instantiates a client
    const pubsub = new PubSub({projectId});
	console.log(`**********Project  ${projectId}.`);
    publishMessage(pubsub,JSON.stringify(req.body));
    // Receive callbacks for new messages on the subscription
    res.send({"mensagem":"api chamada"});
});

async function publishMessage(pubsub,data) {
    var topicName = 'creditapproval-validation-_ENV_';
	console.log(`**********Topic ${topicName}`);
    // Publishes the message as a string, e.g. "Hello, world!" or JSON.stringify(someObject)
    const dataBuffer = Buffer.from(data);

    try {
        const messageId = await pubsub.topic(topicName).publish(dataBuffer);
        console.log(`Message ${messageId} published.`);
    } catch (error) {
        console.error(`Received error while publishing: ${error.message}`);
        process.exitCode = 1;
    }
   }   

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log('Hello world listening on port', port);
});