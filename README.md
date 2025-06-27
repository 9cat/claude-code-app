# claude-code-app
Claude-Code mobile app , write code on the go
1. using the claude-code on the mobile app, and could run in the background for the claude-code running on the remote docker container.
2. so the app could show the cli of the claude code, and also could remeber all the progress and in the local persitant storage for next time to the app start to keep building code
3. default to using github/gitlab to build up the new project , and commit everytime it works as milestone.
4. notify the user the claude-code need people to interact the design / code decision.
5. can use voice record the intraction command and translate to text and then send to claude-cli for easy interaction on the go, so if i am on the car, and travelling in the air could do the coding
6. the app mostly use to transfer idea to code on the fly
7. using flutter could make it work as the web app first and then could compile to android /ios app easily
8. using most docker benifit to deploy docker in docker way to let the application run on the remote server in a clean enviroment
9. verify and testing code and technical document on the fly during the development in case the idea more clear and improving every interaction.
10. keep updating these document to make sure all the roadmap and fix or done , and solve all the issue in the github automatically on the fly
11. it is a open source , so allow all the people to contribute the code to let this app more robositc and reliable.
12. make the idea to product-alpha/beta more efficiency, and also easier to deliever real product team more transparentcy and don't have to explain in a messy way, since all the document is ready in a professional way
13. please polish this README.md in a professional way, since i am using pretty oval way to express my ideas.
14. the repo has ready Dockerfile and docker-compose.yml to create a remote claude-code ready container, just need to docker exec -it claude-code bash , and enter claude , and follow the instruction to using the url to login the claude account and we are good to go with the claude-coding. can we make it smoothly on the app for all of these?
15. so the app suppose to first start will request to enter the ssh ip and port and username and (key file/passowrd) to gain the root permission and auto create the claude-code-docker and then the app will auto interact with this remote docker seemless and then has a chatbox to interact with the claude code remotely.


    
