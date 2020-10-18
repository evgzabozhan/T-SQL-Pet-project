USE [Test_DB]
GO
/****** Object:  StoredProcedure [dbo].[i_magaz]    Script Date: 10/17/2019 2:31:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER proc [dbo].[i_magaz]
@action varchar(50),
@js varchar(max),
@rp varchar(max) out
as 
begin 
set nocount on
begin try
declare @s varchar(50)='Pr0duct-'
			,@id varchar(50)
			,@num varchar(50)
			,@err varchar(max)
			,@errdesc varchar(max)
			,@Complete varchar(max)
			,@sba varchar(50)= substring(@action,1,charindex('.',@action)-1)


		if isnull(@action, '')=''
			begin
				set @errdesc='Не задано действие'
				set @err='err.sys.errnullaction'
				 
				goto err
			end

if @sba in ('product') ---- Продукт
	begin 

	declare @product_name nvarchar(50) = json_value(@js, '$.name'),
			@product_category nvarchar(50) = json_value(@js, '$.category'),
			@product_manufacturer nvarchar(50) = json_value(@js, '$.manufacturer'),
			@product_description nvarchar(300) = json_value(@js, '$.description'),
			@product_price money = json_value(@js, '$.price'),
			@product_count int = json_value(@js, '$.count'),
			@product_id varchar(50) = json_value(@js,'$.id'),
			@product_license nvarchar(50) = isnull(json_value(@js, '$.lis_id'),
						(select top 1 id from [dbo].[product] where license=json_value(@js, '$.license'))
						)

	if @action in ('product.create') ---- создаем продукт
			begin 

				if (@product_name is null or @product_category is null or @product_manufacturer is null or @product_description is null
					or @product_price is null  or @product_count is null) ---- проверка 
					begin 

						set @errdesc='Не заполнены обязательные поля.'
						set @err='err.product.unset_field'

						goto err

					end

				if exists (select top 1 1 from [dbo].[product] where product = @product_name)
					begin 

						set @errdesc='Уже существует продукт с таким именем в этой системе.'
						set @err='err.product.exists'

						goto err

					end

				set @product_license =@s+cast(next value for [dbo].[product_license] as varchar)
				set @id=newid()

				insert into [dbo].[Product](id,license,product,category,manufacturer,pdescription,pcount,price)
						values (@id,@product_license,@product_name,@product_category,@product_manufacturer,@product_description,@product_count,@product_price)
			

				set @rp=
							(
								select @id id,@product_license license for json path, without_array_wrapper
							)

					goto ok
				end


	if @action in ('product.update') 
			begin 

				update Product
				set category = isnull(@product_category,category),
					manufacturer = isnull(@product_manufacturer,manufacturer),
					pdescription = isnull(@product_description,pdescription),
					pcount = isnull(@product_count,pcount),
					price = isnull(@product_price,price)
				where id = @product_id

				set @rp = 
						(
						 select * from Product where id = @product_id for json path,without_array_wrapper
						 )

				goto ok
			end
					
				
	if @action in ('product.count')
			begin

				update [dbo].[product] 
					set pcount = pcount - @product_count
				where id = @product_id or product = @product_name

				set @rp = 
						(
						 select * from product where id = @product_id for json path,without_array_wrapper
						 )

				goto ok

			end


	if @action in ('product.delete')
		begin 

			if exists(select top 1 1 id from Product where id = @product_id)
			begin

				delete from product
					where id = @id 
					
				set @rp = 
						( 
							select 'Продукт успешно удален' comment for json path,without_array_wrapper
						)

				goto ok

			end
				else
					begin

						set @errdesc='Продукт не найден'
						set @err='err.product.exists'

						goto err

					end

		end


	if @action in ('product.info')---Получение общей информации о продукте
		begin
			
			set @rp=
					(
						select * from [dbo].[product] 
							where product=@product_name or id=@product_id
						for json path, without_array_wrapper
					)

			goto ok
		end

	end


if @sba in ('discount') ---- Скидки
	begin
		declare
			@discount_id nvarchar(50) = json_value(@js,'$.id'),
			@product_disc_id nvarchar(50) = json_value(@js,'$.product_id'),
			@product_discounted nvarchar(50) = json_value(@js,'$.product'),
			@p_count int = json_value(@js,'$.count'),
			@discount_price money = json_value(@js,'$.discount'),
			@status_discount nvarchar(50) = 'active'


	if @action in ('discount.create') ---- создание скидки
		begin 

			if not exists (select top 1 1 from product where product = @product_discounted)
				begin 

					set @errdesc = 'Такого продукта не существует'
					set @err = 'err.discount.notextist'

				end

			if(@product_discounted is null or @p_count is null or @discount_price is null)
				begin
					
					set @errdesc='Не заполнены обязательные поля'
					set @err='err.discount.unset_filed'

					goto err

				end

			if exists (select top 1 1 from discount where product = @product_discounted)
				and (select stat from discount where product = @product_discounted) = 'active'

				begin 
					
					set @errdesc = 'Скидка на этот продукт уже существует'
					set @err = 'err.discount.exists'

					goto err

				end
			
			set @discount_id = newid()
			set @discount_price = (select price from product where product = @product_discounted) - (((select price from product where product = @product_discounted) / 100) * @discount_price)
			
			declare 
				@js_disc nvarchar(max) = (select @product_disc_id id,@product_discounted [name], @p_count [count] for json path,without_array_wrapper),
				@rp_disc nvarchar(max)

			exec [dbo].[i_magaz] 'product.count',@js_disc,@rp_disc out

			if (select json_value(@rp_disc,'$.status'))<>'ok'
					begin
						
						set @errdesc='Операция не выполнена'
						set @err='err.discount.error'
						
						goto err
					end


			insert into discount(id,p_id,product,pcount,discount,stat)
				values(@discount_id,@product_disc_id,@product_discounted,@p_count,@discount_price,@status_discount)




			set @rp=
						(
							select @discount_id id for json path, without_array_wrapper
						)

			goto ok
				
	end 


	if @action in ('discount.inactive') ---- изменение скидки на неактивную
		begin

			if not exists (select top 1 1 from product where product = @product_discounted)
				begin 

					set @errdesc = 'Такой скидки не существует'
					set @err = 'err.discount.notexists'

				end
				
				if (@status_discount <> (select top 1 stat from discount where product = @product_discounted))
					begin 

						set @errdesc='Эта карта уже неактивна.'
						set @err='err.clientcard.inactive'

					goto err

					end

					set @status_discount = 'inactive'
				
					update discount
					
						set stat = @status_discount

					where product = @product_discounted
					

						set @rp = 
									(
										select @status_discount status, @product_discounted product for json path, without_array_wrapper
									)
						goto ok

		end


	if @action in ('discount.info') ---- общая информация о скидке
		begin 
			
			set @rp = 
			(
				select * from discount where product = @product_discounted for json path,without_array_wrapper
			)

			goto ok
		end

	end


if @sba in ('category') ---- Категория
	begin 
		
		declare 
			@category_id nvarchar(50) = json_value(@js,'$.id'),
			@category_name nvarchar(50) = json_value(@js,'$.name'),
			@category_description nvarchar(300) = json_value(@js, '$.description')

	if @action in ('category.create') ---- создание категории
			begin
				if (@category_name is null or @category_description is null) ---- проверка 
				
						begin 

							set @errdesc='Не заполнены обязательные поля.'
							set @err='err.category.unset_field'
							
							goto err	

						end

					if exists (select top 1 1 from [dbo].[category] where category = @category_name) 
						begin 

							set @errdesc='Уже существует категория с таким именем в этой системе.'
							set @err='err.category.exists'

							goto err

						end

					set @category_id = newid()

					insert into Category (id,category,cdescription)
						values(@category_id,@category_name,@category_description)

					set @rp=
							(
								select @category_id id for json path, without_array_wrapper
							)

					goto ok

				end


	if @action in ('category.update') --- Обновление категории
			begin 
				
				update category
					set category = isnull(@category_name,category),
						cdescription = isnull(@category_description,cdescription)
				where id = @category_id
				
				set @rp=
							(
								select * from category where category=@category_id for json path, without_array_wrapper
							)

				goto ok

			end


	if @action in ('category.info')---Получение общей информации о категории
			begin
				set @rp=
						(
							select * from [dbo].[category] where category=@category_id for json path, without_array_wrapper
						)

				goto ok
			end

		
	if @action in ('category.delete') ---- удаление категории
			begin 

				delete from category 
					where category = @category_id
				
				goto ok
			end

	end

		
if @sba in ('client')  ---- Клиент
	begin 
		
		declare 
			@clientid nvarchar(50) = json_value(@js,'$.id'),
			@client_login nvarchar(50) = json_value(@js,'$.login'),
			@client_fio nvarchar(300) = json_value(@js, '$.fio'),
			@client_mail nvarchar(100) = json_value(@js,'$.email'),
			@client_phone nvarchar(15) = json_value(@js,'$.phone'),
			@client_card nvarchar(100) = json_value(@js, '$.card'),
			@client_bank nvarchar(100) = json_value(@js,'$.bank'),
			@status_c nvarchar(10) = 'active'
	

	if @action in ('client.create')
		begin 

			if (@client_fio is null or @client_login is null or @client_phone is null or @client_card is null or @client_bank is null)
				begin

					set @errdesc='Не заполнены обязательные поля.'
					set @err='err.client.unset_field'

					goto err

				end


			if  exists (select top 1 1 from [dbo].[client] where fio = @client_fio or clogin = @client_login)

				begin 

					set @errdesc='Уже существует клиент с таким именем/логином в этой системе.'
					set @err='err.client.exists'

					goto err

				end

			if exists (select top 1 1 from [dbo].[client] where phone = @client_phone) 
				begin 

					set @errdesc='Уже существует клиент с таким номером в этой системе.'
					set @err='err.client.number_exists'

					goto err

				end

			if exists (select top 1 1 from [dbo].[client] where c_card = @client_card) 
				begin 

					set @errdesc='Уже существует клиент с такой картой в этой системе.'
					set @err='err.client.Card_exists'

					goto err

				end

			if exists (select top 1 1 from [dbo].[client] where mail = @client_mail) 
				begin 

					set @errdesc='Уже существует клиент с таким email в этой системе.'
					set @err='err.client.email_exists'

					goto err

				end

			set @ClientID = newid()

			insert into Client (id,clogin,fio,mail,phone,c_card,stat)
				values(@clientid,@client_login,@client_fio,@client_mail,@client_phone,@client_card,@status_c)


			declare @rp_client nvarchar(max) , @js_card nvarchar(max) = (select @client_card num, @client_bank bank for json path, without_array_wrapper)
			
			exec [dbo].[i_magaz] 'clientcard.create',@js_card,@rp_client

			if (select json_value(@rp_client,'$.status'))<>'ok'
					begin
						
						set @errdesc='Операция не выполнена'
						set @err='err.cardcreate.error'
						
						goto err
					end

			set @rp=
					(
						select @clientid id for json path, without_array_wrapper
					)

			goto ok	

		end


	if @action in ('client.inactive') --- перевод статуса клиента в неактивный
			begin 

				if exists (select top 1 1 from client where id = @clientid)
					begin

						if (@status_c <> (select top 1 stat from client where id = @clientid))
							begin 

								set @errdesc='Этот клиент уже неактивен.'
								set @err='err.client.inactive'

							goto err

							end
						
						set @status_c = 'inactive'

						update client
							set stat = @status_c
							where clogin = @client_login or id=@clientid

						declare @rp_s nvarchar(max),@js_client nvarchar(max) = (select @client_card num for json path,without_array_wrapper)
						exec [dbo].[i_magaz] 'clientcard.inactive',@js_client,@rp_s out

						if (select json_value(@rp_s,'$.status'))<>'ok'
							begin
						
								set @errdesc='Операция не выполнена'
								set @err='err.Order.ERROR_COUNT'
						
								goto err
							end

						goto ok

					end

			end


	if @action in ('client.info')---Получение общей информации о клиенте
			begin
			
				set @rp=
						(
							select * from [dbo].[client] where clogin=@client_login or id=@clientid for json path, without_array_wrapper
						)

				goto ok

			end

end


if @sba in ('clientcard')  ---- Карта клиента
	begin 
			
	declare 
			@num_card nvarchar(50) = json_value(@js, '$.num'),
			@card_fio nvarchar(100) = json_value(@js,'$.fio'),
			@card_client_id nvarchar(50) = json_value(@js,'$.id'),
			@bank nvarchar(300) = json_value(@js, '$.bank'),
			@status nvarchar(10) = 'active'
			
	

	if @action in ('clientCard.create') --- создание карты клиента
		begin 

			if (@num_card is null or @bank is null)
				begin

					set @errdesc='Не заполнены обязательные поля.'
					set @err='err.card.unset_field'

					goto err

				end
			

			if exists (select top 1 1 from [dbo].[clientcard] where num = @num_card) 
				begin 

					set @errdesc='Уже существует карта с таким номером в этой системе.'
					set @err='err.card.exists'

					goto err

				end

				
			select top 1 @card_fio = fio , @card_client_id = id
				from [dbo].[client] 
			where c_card = @num_card and stat = 'active'

			insert into clientcard (num,fio,c_id,bank,stat)
				values(@num_card,@card_fio,@card_client_id,@bank,@status)

			set @rp =
						(
							select @num_card id for json path, without_array_wrapper
						)

			goto ok

		end 


	if @action in ('clientcard.inactive') ---  перевод карты в статус неактивно 
			begin

			if exists (select top 1 1 from clientcard where num = @num_card)
				begin 
				
				if (@status <> (select top 1 stat from clientcard where num = @num_card))
					begin 

						set @errdesc='Эта карта уже неактивна.'
						set @err='err.clientcard.inactive'

					goto err

					end

				
						update clientcard
					
							set stat = @status

						where num = @num_card
					

						set @rp = 
									(
										select @status status, @num_card num for json path, without_array_wrapper
									)
						goto ok

				end
			end
			

	if @action in ('clientCard.info')---Получение общей информации о карте
			begin
			
				set @rp =
						(
							select * from [dbo].[clientcard] where num=@num_card for json path, without_array_wrapper
						)

				goto ok
			end	

end


if @sba in ('order')  ---- Заказ
	begin 
		
	declare 
			@order_id nvarchar(50),
			@discount nvarchar(50) = json_value(@js,'$.discount'),
			@client_id nvarchar(100) = json_value(@js,'$.id'),
			@client_order_fio nvarchar (300) = json_value(@js,'$.fio'),
			@prodid_order nvarchar(50) = json_value(@js,'$.product_id'),
			@product_name_order nvarchar(50) = json_value(@js,'$.product_name'),
			@order_product_count int = json_value(@js, '$.count'),
			@card_num nvarchar(50),
			@price money,
			@with_discount nvarchar(50)
			
	

	if @action in ('order.create')--- создание заказа
		begin 

			if (@client_id is null or @prodid_order is null)
				begin

					set @errdesc='Не заполнены обязательные поля.'
					set @err='err.order.unset_field'

					goto err

				end

			if ((select top 1 stat from client where id = @client_id) <> 'active')
				begin

					set @errdesc = 'Невозможно создать заказ от неактивного клиента'
					set @err = 'err.order.clientnotactive'

					goto err
						
				end
			
			if (@order_product_count > (select top 1 pcount from Product where id = @prodid_order))
				begin 

					set @errdesc='Такого количества товара нет на складе.'
					set @err='err.order.count_error'

					goto err

				end

				
				set @order_id = newid()

				select top 1 
					@card_num = c_card,
					@client_order_fio = fio 
				from [dbo].[Client]
				where id = @client_id

				if(@discount is not null) and 
				exists(select top 1 1 from discount where id = @discount)
					begin 

					if (@order_product_count > (select top 1 pcount from discount where id = @discount))
						begin 

							set @errdesc='Такого количества товара нет на складе.'
							set @err='err.order.count_error'

							goto err

						end

						select top 1
						@product_name_order = product,
						@price = @order_product_count * discount
						
						from [dbo].[discount]
							where @discount = id 

						
						update [dbo].[discount]

						set pcount = pcount - @order_product_count

						where id = @discount

						set @with_discount = 'yes'
				
				insert into Orders (id,c_id,c_fio,p_id,product,p_count,num_card,price,discount)
					values(@order_id,@client_id,@client_order_fio,@prodid_order,@product_name_order,@order_product_count,@card_num,@price,@with_discount);

					declare 
						@rp_log nvarchar(max),
						@js_log nvarchar(max) = 
						(select
							@order_id id,
							@client_id client_id,
							@client_order_fio fio,
							@prodid_order p_id,
							@product_name_order pname,
							@order_product_count count,
							@card_num num,
							@price price,
							@with_discount discount 
						for json path,without_array_wrapper)

						exec [dbo].[i_magaz] 'order.log',@js_log,@rp_log out

						if (select json_value(@rp_log,'$.status'))<>'ok'
					begin
						
						set @errdesc='Операция не выполнена'
						set @err='err.log.error'
						
						goto err
					end

				set @rp=
						(
							select @order_id id for json path, without_array_wrapper
						)

				 goto ok

					end

				select top 1 
					@product_name_order = product,
					@price = @order_product_count * price
				from [dbo].[product]
				where id = @prodid_order
				

				declare @rp_ nvarchar(max)
				,@js_dop varchar(max) = (select @order_product_count count,@prodid_order id for json path,without_array_wrapper)


				exec [dbo].[i_magaz] 'product.count',@js_dop,@rp_ out


				if (select json_value(@rp_,'$.status'))<>'ok'
					begin
						
						set @errdesc='Операция не выполнена'
						set @err='err.order.count'
						
						goto err
					end

					set @with_discount = 'no'
				
				insert into Orders (id,c_id,c_fio,p_id,product,p_count,num_card,price,discount)
					values(@order_id,@client_id,@client_order_fio,@prodid_order,@product_name_order,@order_product_count,@card_num,@price,@with_discount);
					
					declare 
						@rp_logn nvarchar(max),
						@js_logn nvarchar(max) = 
						(select
							@order_id id,
							@client_id client_id,
							@client_order_fio fio,
							@prodid_order p_id,
							@product_name_order pname,
							@order_product_count count,
							@card_num num,
							@price price,
							@with_discount discount 
						for json path,without_array_wrapper)


						exec [dbo].[i_magaz] 'order.log',@js_logn,@rp_logn out

						if (select json_value(@rp_logn,'$.status'))<>'ok'
					begin
						
						set @errdesc='Операция не выполнена'
						set @err='err.log.error'
						
						goto err
					end

				set @rp=
						(
							select @order_id id for json path, without_array_wrapper
						)

				 goto ok
			end


	if @action in ('order.cancel')---отмена заказа 
			begin 
				
				declare @order_cancel nvarchar(50) = json_value(@js, '$.order_cancel'),
						@product_order nvarchar(50),
						@product_count_order int

				if exists (select top 1 1 from orderlog where order_id = @order_cancel and stat = 'complete')
					begin 

						set @errdesc = 'Вы не можете отменить оплаченный заказ'
						set @err = 'err.order.cancel_payment'

						goto err

					end

				if not exists (select top 1 1  from orders where id = @order_cancel)
					begin 

						set @errdesc='Такого заказа не существует.'
						set @err='err.order.not_exists'

						goto err
						
					end

				if exists (select top 1 1 from orders where  id = @order_cancel)
					begin

						select top 1
							@product_order = p_id,
							@product_count_order = p_count
						from orders where id = @order_cancel
						



							if ((select top 1 discount from orders where p_id = @product_order) like 'yes')
								begin

									update discount	
									set pcount = pcount + @product_count_order
									where p_id = @product_order

									insert into orderlog (orderdate,order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,stat)
										select getdate(),order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,'canceled' 
										from orderlog
										where order_id = @order_cancel
									

									delete from orders
									where id = @order_cancel

									goto ok

								end

						update Product	
							set pcount = pcount + @product_count_order
						where id = @product_order

						insert into orderlog (orderdate,order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,stat)
										select getdate(),order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,'canceled' 
										from orderlog
										where order_id = @order_cancel

						delete from orders
							where id = @order_cancel	

						goto ok
					end 

					
			end

				
	if @action in ('order.info')---Получение общей информации о заказе
			begin
			
				set @rp=
						(
							select * from [dbo].[orders] where c_id=@client_id for json path, without_array_wrapper
						)

				goto ok
			end	


	if @action in ('order.log') --- занесение логов
		begin 

			declare 
				@order_date datetime = getdate(),
				@orderl_id nvarchar(50) = json_value(@js,'$.id'),
				@order_clientid nvarchar(50) = json_value(@js,'$.client_id'),
				@client_order_fiol nvarchar(50) = json_value(@js,'$.fio'),
				@prodid_orderl nvarchar(50) = json_value(@js,'$.p_id'),
				@product_name_orderl nvarchar(50) = json_value(@js,'$.pname'),
				@order_product_countl int = json_value(@js,'$.count'),
				@card_numl nvarchar(50) = json_value(@js,'$.num'),
				@pricel money = json_value(@js,'$.price'),
				@with_discountl nvarchar(4) = json_value(@js,'$.discount'),
				@status_ord nvarchar (10) = 'create'

			if exists (select top 1 order_id from orderlog where order_id = @orderl_id and stat = 'complete')
				begin

					set @errdesc = 'Данный заказ уже оплачен'
					set @err = 'err.orderlog.ordercomplite'

					goto err

				end


			insert into orderlog(orderdate,order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,stat)
				values(
				@order_date,
				@orderl_id,
				@order_clientid,
				@client_order_fiol,
				@prodid_orderl,
				@product_name_orderl,
				@order_product_countl,
				@card_numl,
				@pricel,
				@with_discountl,
				@status_ord
				)

				set @rp = 
						(
							select * from orderlog where order_id = @orderl_id for json path,without_array_wrapper
						)
				goto ok

		end
	end


if @sba in ('payment') --- Оплата
	begin 

		declare 
			@payday datetime,
			@payment money = json_value(@js,'$.pay'),
			@paym_ord nvarchar(50) = json_value(@js,'$.order'),
			@paym_card nvarchar(50) = json_value(@js,'$.card'),
			@paym_status nvarchar(10),
			@product_id_paym nvarchar(50)

	if @action in ('payment.begin')
		begin 

			if ((select top 1 stat from [dbo].[payment] where order_id = @paym_ord) = 'pair')
				begin 

					set @errdesc = 'Данный заказ уже оплачен'
					set @err = 'err.payment.exists'

					goto err

				end

			if ((select top 1 stat from [dbo].[orderlog] where order_id = @paym_ord) <> 'create')
				begin 

					set @errdesc = 'Данный заказ отменен или уже оплачен'
					set @err = 'err.payment.notexists'

					goto err

				end

			if (@payment < (select price from [dbo].[orders] where id = @paym_ord))
				begin 

					set @errdesc = 'Недостаточно средств для оплаты'
					set @err = 'err.payment.notfounds'

					goto err

				end


			if (@payment > (select price from [dbo].[orders] where id = @paym_ord))
				begin 

					set @errdesc = 'Количество средств превышает необходимое количество'
					set @errdesc = 'err.payment.muchmoney'

					goto err

				end


			if (@payment = (select price from [dbo].[orders] where id = @paym_ord))
				begin 
					
					set @payday = getdate()
					set @paym_status = 'pair'
					set @product_id_paym = (select p_id from [dbo].[orders] where id = @paym_ord)

					insert into payment (paymdate,payment,order_id,num_card,stat)
						values (@payday,@payment,@paym_ord,@paym_card,@paym_status)

			if exists (select top 1 order_id from [dbo].[orderlog] where order_id = @paym_ord and stat = 'complete')
				begin

					set @errdesc = 'Данный заказ уже оплачен'
					set @err = 'err.orderlog.ordercomplite'

					goto err

				end

					insert into orderlog (orderdate,order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,stat)
										select getdate(),order_id,client_id,fio,product_id,product,p_count,c_card,price,discount,'complete' 
										from orderlog
										where order_id = @paym_ord

					set @rp = 
						(
							select top 1 license from product where id = @product_id_paym for json path,without_array_wrapper
						)

					goto ok

				end
		end
end
	

	end try
	begin catch
		
		set @errdesc= ERROR_MESSAGE()
		set @err='err.sys'

		goto err

	end catch 


err:


	set @rp=
	(
		select 'err' [status],lower(@s+'.'+@err) err , @errdesc errdesc for json path, without_array_wrapper
	)return

ok:

	set @rp=
	(
		select 'ok' [status],json_query(@rp) response for json path, without_array_wrapper
	)return

END
