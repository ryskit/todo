require 'rails_helper'

RSpec.describe Api::V1::TasksController, type: :controller do
  
  TASK_SIZE = 51
  
  before :each do
    @user = create(:user)
    payload = { :uuid => @user.uuid, :name => @user.name }
    access_token = Token.create_access_token(payload)
    refresh_token = @user.refresh_tokens.create

    @user_tokens = {
      access_token: access_token,
      refresh_token: refresh_token.token,
      refresh_token_exp: refresh_token.expiration_at.to_i,
    }
    
    
    @tasks = []
    TASK_SIZE.times{
      task = @user.tasks.create(attributes_for(:update_task_attributes))
      @tasks.push(task)
    }

    controller.request.headers['Authorization'] = "Bearer #{@user_tokens[:access_token]}"
    controller.request.headers['CONTENT_TYPE'] = 'application/json'
  end
  
  describe 'GET#index' do
    context 'アクセストークンが有効な場合' do
      it 'タスクの一覧を取得する' do
        get :index, params: {}
        expect(response).to have_http_status(:ok)
        res_body = JSON.parse(response.body)
        # 現状50件まで
        expect(res_body['tasks'].size).not_to eq TASK_SIZE
      end
    end
    
    context 'アクセストークンが無効な場合' do
      it 'unauthorized errorとなる' do
        controller.request.headers['Authorization'] = 'Bearer aaaaaaaaaaaaaaaaaaaaaaaaa'
        get :index, params: {}
        expect(response).to have_http_status(:unauthorized)
        
        res_body = JSON.parse(response.body)
        expect(res_body['error']).to eq Rack::Utils::HTTP_STATUS_CODES[401]
      end
    end
  end
  
  describe 'GET#show' do

    let(:update_task_attributes) { attributes_for(:update_task_attributes) }
    let(:created_task) { @tasks.first }
    
    describe 'アクセストークンが有効な場合' do
      it '特定のタスクを取得する' do
        get :show, params: { id: created_task['id'] }
        expect(response).to have_http_status(:ok)
        res_body = JSON.parse(response.body)

        expect(res_body['task'][0]['id']).to eq created_task[:id]
        expect(res_body['task'][0]['title']).to eq created_task[:title]
        expect(res_body['task'][0]['content']).to eq created_task['content']
      end
      
      it 'タスクのIDが存在しない、または、自身のタスクのIDをパラメータとして渡した場合、エラーが返る' do
        get :show, params: { id: 0 }
        expect(response).to have_http_status(404)
      end
    end
    
    describe 'アクセストークンが無効の場合' do
      it 'unauthorized errorとなる' do
        controller.request.headers['Authorization'] = 'Bearer aaaaaaaaaaaaaaaaaaaaaaaaa'
        get :show, params: { id: created_task['id'] }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
  
  describe 'POST#create' do

    let(:valid_task_attributes) { { task: attributes_for(:valid_task_attributes) } }
    let(:invalid_task_attributes) { { task: attributes_for(:invalid_task_attributes) } }

    describe 'アクセストークンが有効な場合' do
      
      context '有効なパラメータの場合' do
        it 'タスクを新規作成' do
          expect {
            post :create, params: valid_task_attributes
          }.to change(Task, :count).by(1)
          
          res_body = JSON.parse(response.body)
          expect(res_body['title']).to eq valid_task_attributes[:title]
          expect(res_body['content']).to eq valid_task_attributes[:content]
        end
      end

      context '無効なパラメータの場合' do
        it 'タイトルが空の場合はエラーとなる' do
          post :create, params: invalid_task_attributes

          res_body = JSON.parse(response.body)
          expect(res_body['status']).to eq 'NG'
          expect(res_body['error']).to eq Rack::Utils::HTTP_STATUS_CODES[400]
          expect(res_body['messages'].present?).to be true
          expect(res_body['messages']['title'].present?).to be true
        end
      end
      
    end

    describe 'アクセストークンが無効な場合' do
      it 'unauthorized errorとなる' do
        controller.request.headers['Authorization'] = 'Bearer aaaaaaaaaaaaaaaaaaaaaaaaa'
        post :create, params: valid_task_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
  
  
  describe 'PATCH#update' do
    
    let(:update_task_attributes) { attributes_for(:update_task_attributes) }
    let(:update_invalid_task_attributes) { attributes_for(:update_invalid_task_attributes) }
    let(:created_task) { @tasks.first }
    
    describe 'アクセストークンが有効な場合' do
      context '有効なパラメータの場合' do
        it 'タスクを更新する'do
          expect do
            patch :update, params: { id: created_task['id'], task: update_task_attributes }
          end.to change(Task, :count).by(0)
          expect(response).to have_http_status(200)
          
          res_body = JSON.parse(response.body)
          expect(res_body['task']['id']).to eq created_task['id']
          expect(res_body['task']['title']).not_to eq created_task['title']
          expect(res_body['task']['content']).not_to eq created_task['content']
          expect(res_body['task']['due_to']).to be >= created_task['due_to']
        end
        
        it 'タスクのIDが存在しない、または自身のタスクのIDでない場合、エラーが返される'do
          expect do
            patch :update, params: { id: 0, task: update_task_attributes }
          end.to change(Task, :count).by(0)
          expect(response).to have_http_status(400)
          
          res_body = JSON.parse(response.body)
          expect(res_body['messages'].nil?).to be true
        end
        
        it 'リクエストしたタスクの値がバリデーションエラーとなった場合、エラーが返される'do
          expect do
            patch :update, params: { id: created_task[:id], task: update_invalid_task_attributes }
          end.to change(Task, :count).by(0)
          expect(response).to have_http_status(400)
          
          res_body = JSON.parse(response.body)
          expect(res_body['messages'].present?).to be true
        end
      end
    end
    
    describe 'アクセストークンが無効な場合' do
      it 'unauthorized errorとなる' do
        controller.request.headers['Authorization'] = 'Bearer aaaaaaaaaaaaaaaaaaaaaaaaa'
        patch :update, params: { id: created_task['id'], task: update_task_attributes }
        expect(response).to have_http_status(:unauthorized)

        res_body = JSON.parse(response.body)
        expect(res_body['status']).to eq 'NG'
        expect(res_body['error']).to eq Rack::Utils::HTTP_STATUS_CODES[401]
      end
    end
  end
  
  
  describe 'DELETE#destory' do
    
    let(:update_task_attributes) { attributes_for(:update_task_attributes) }
    let(:created_task) { @tasks.first }
    
    context 'アクセストークンが有効な場合' do
      it 'タスクを削除することができる' do
        expect do
          delete :destroy, params: { id: created_task['id'] }
        end.to change(Task, :count).by(-1)
        expect(response).to have_http_status(204)
        res_body = JSON.parse(response.body)
        expect(res_body.blank?).to be true
      end
      
      it 'タスクのIDが存在しない、または自身が作成したタスクのIDでない場合エラーとなる' do
        expect do
          delete :destroy, params: { id: 0 }
        end.to change(Task, :count).by(0)
        expect(response).to have_http_status(400)
        res_body = JSON.parse(response.body)
        expect(res_body.blank?).to be false
      end
    end
    
    context 'アクセストークンが無効な場合' do
      it 'authorized errorとなる' do
        controller.request.headers['Authorization'] = 'Bearer aaaaaaaaaaaaaaaaaaaaaaaaa'
        delete :destroy, params: { id: created_task['id'] }
        expect(response).to have_http_status(:unauthorized)

        res_body = JSON.parse(response.body)
        expect(res_body['status']).to eq 'NG'
        expect(res_body['error']).to eq Rack::Utils::HTTP_STATUS_CODES[401]
      end
    end
  end
end
