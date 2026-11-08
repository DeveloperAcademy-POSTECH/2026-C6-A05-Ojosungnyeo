<img width="20000" alt="썸네일" src="https://github.com/user-attachments/assets/fca05b05-aa73-486b-a9f0-f99c99461c1a" />



# 👽 따또 개발 배경

> 왜 친구와 여행 가서 싸우는 일이 생길까요?

같은 여행을 떠나도 **`가고 싶은 장소와 여행을 즐기는 방식은 서로 다르기 때문`** 입니다.

문제는 서로 다른 취향 자체보다 그 차이를 어떻게 맞춰야 할지 몰라 서로의 눈치를 보게 된다는 점입니다.

실제로 따로 여행하고 싶었지만 하지 못했던 인터뷰 참여자들은 친구를 기다리게 하거나 서운하게 할까 봐 따로 움직이자는 말을 꺼내지 못했고 결국 원하는 경험을 포기한 채 여행을 마쳤습니다.

**저희는 이러한 경험을 통해 각자의 선택을 부담 없이 드러내고 서로의 여행을 자연스럽게 조율할 방법이 필요하다고 보았습니다.**

# 👽 따또의 탄생 배경

<img width="800" alt="image" src="https://github.com/user-attachments/assets/39412827-e092-4bf3-ab68-710274a10c7c" />


따또는 우주 어딘가의 포테이토별에서 시작되었습니다.

모험심 많은 외계인 A는 새롭게 발견된 작은 행성, 지구로 친구들과 여행을 떠납니다. 하지만 누구는 캐릭터숍에 가고 싶고, 누구는 카페를 싫어하는 등 서로 다른 취향 때문에 여행 코스가 흔들리기 시작합니다.

함께 여행하고 싶은 마음은 같지만 하고 싶은 것은 다른 친구들.
이들이 **`각자의 취향을 포기하지 않고 따로 또 같이 여행하는 방법을 찾아가는 과정`에서 따또가 탄생했습니다.**

따또는 친구들을 여행방에 초대하고, 각자가 가고 싶은 장소를 바탕으로 함께할 사람과 코스를 조율합니다. 완성된 그룹별 일정과 이동 경로를 한눈에 보여주어 취향이 달라도 누구 하나 원하는 경험을 포기하지 않고 **따로 또 같이 여행할 수 있도록 돕습니다.**

> 서로의 취향을 같게 만드는 대신, 다른 취향이 하나의 여행 안에서 공존하도록.
따또가 당신의 즐거운 지구 여행을 책임집니다.


# 👽 Project Design

|  Architecture |
| :-------------: | 
| <img src = "https://github.com/user-attachments/assets/79e54aef-1efc-4929-877e-386b7c458976" width ="800">  |


| Screen flow   |    Dependency call map |
|:----------: | :----------: |
| <img src = "https://github.com/user-attachments/assets/e77874fc-aba0-4fee-8dc5-5c761e563b30" width ="700">  |  <img src = "https://github.com/user-attachments/assets/404a5490-b8de-4b99-a58d-666136ca6e48" width ="645">  |

# 👽 App Flow

<img width="3000" alt="image" src="https://github.com/user-attachments/assets/16858b6a-d570-436b-8e45-94e0a99e0ace" />


### **1. 여행 생성 및 친구 초대**

- 여행 지역과 기간을 설정해 새로운 여행 생성
- 초대 링크를 공유해 함께 여행할 친구 모집

### **2. 각자의 여행 취향을 반영한 그룹 제안 및 조율**

- 각자 `꼭 가고 싶은 장소`를 저장하면, 앱이 이동수단과 시간을 고려해 지역별로 분류
- `방문 희망 장소와 취향을 바탕`으로 `함께 또는 따로 여행할 그룹 초안` 제안
- 서로의 취향을 존중하며 그룹 구성과 방문 장소를 자유롭게 조율하고 확정

### **3. 함께 또는 따로 이동할 여행 동선 구성**

- 확정된 여행 그룹과 방문 장소를 바탕으로 날짜별 방문 순서 구성
- `함께하는 그룹`과 `따로 여행하는 그룹`의 이동 동선을 지도 위에서 한눈에 확인


## 🐹 Team Members
| 👽 Heather / [김민서](https://github.com/kkdew3)  |    🍔 Grace / [김하은](https://github.com/glace0x)    |    ☀️ Juni / [선영주](https://github.com/dudwntjs)  |  🌻 Jardin / [최정원](https://github.com/frutacruda)   |    🥔 Tay / [한민주](https://github.com/mju0805)  |  
| :-------------: | :----------: | :----------: |:----------: |:----------: |
| <img src = "https://github.com/user-attachments/assets/c682693b-771b-4dcb-90c0-4a5391307221" width ="200">  | <img src = "https://github.com/user-attachments/assets/54b3d34f-82f2-4b80-98da-02d101019b8c" width ="200">  |  <img src = "https://github.com/user-attachments/assets/9f4bb9f0-40ce-4daf-85e0-30987b0605b5" width ="200">  | <img src = "https://github.com/user-attachments/assets/d66d08c7-ae4a-418c-b76f-2b0ff673452b" width ="200">  | <img src = "https://github.com/user-attachments/assets/34735cc4-835a-4db6-82d3-58c0297ba4ed" width ="200">  | 
|    Design   |   Design   |  Tech   |   Tech   |    Tech | 
